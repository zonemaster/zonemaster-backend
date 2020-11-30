package Zonemaster::Backend::DB::SQLite;

our $VERSION = '1.1.0';

use Moose;
use 5.14.2;

use DBI qw(:utils);
use JSON::PP;
use Digest::MD5 qw(md5_hex);
use Log::Any qw( $log );

use Zonemaster::Backend::Config;

with 'Zonemaster::Backend::DB';

has 'config' => (
    is       => 'ro',
    isa      => 'Zonemaster::Backend::Config',
    required => 1,
);

has 'dbh' => (
    is  => 'rw',
    isa => 'DBI::db',
);

sub BUILD {
    my ( $self ) = @_;

    if ( !defined $self->dbh ) {
        my $connection_string = $self->config->DB_connection_string( 'sqlite' );
        $log->debug( "Connection string: " . $connection_string );

        my $dbh = DBI->connect(
            $connection_string,
            {
                AutoCommit => 1,
                RaiseError => 1,
            }
        ) or die $DBI::errstr;
        $log->debug( "Database filename: " . $dbh->sqlite_db_filename );

        $self->dbh( $dbh );
    }

    return $self;
}

sub DEMOLISH {
    my ( $self ) = @_;
    $self->dbh->disconnect() if $self->dbh;
}

sub create_db {
    my ( $self ) = @_;

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $self->dbh->do( 'DROP TABLE IF EXISTS test_specs' ) or die "SQLite Fatal error: " . $self->dbh->errstr() . "\n";

    $self->dbh->do( 'DROP TABLE IF EXISTS test_results' ) or die "SQLite Fatal error: " . $self->dbh->errstr() . "\n";

    $self->dbh->do(
        'CREATE TABLE test_results (
                         id integer PRIMARY KEY AUTOINCREMENT,
                         hash_id VARCHAR(16) DEFAULT NULL,
                         domain VARCHAR(255) NOT NULL,
                         batch_id integer NULL,
                         creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                         test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                         test_end_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                         priority integer DEFAULT 10,
                         queue integer DEFAULT 0,
                         progress integer DEFAULT 0,
                         params_deterministic_hash character varying(32),
                         params text NOT NULL,
                         results text DEFAULT NULL,
                         undelegated boolean NOT NULL DEFAULT false,
                         nb_retries integer NOT NULL DEFAULT 0
               )
     '
    ) or die "SQLite Fatal error: " . $self->dbh->errstr() . "\n";

    ####################################################################
    # BATCH JOBS
    ####################################################################
    $self->dbh->do( 'DROP TABLE IF EXISTS batch_jobs' ) or die "SQLite Fatal error: " . $self->dbh->errstr() . "\n";

    $self->dbh->do(
        'CREATE TABLE batch_jobs (
                         id integer PRIMARY KEY,
                         username character varying(50) NOT NULL,
                         creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
               )
     '
    ) or die "SQLite Fatal error: " . $self->dbh->errstr() . "\n";

    ####################################################################
    # USERS
    ####################################################################
    $self->dbh->do( 'DROP TABLE IF EXISTS users' );
    $self->dbh->do(
        'CREATE TABLE users (
                         id integer primary key,
                         user_info json DEFAULT NULL
               )
     '
    ) or die "SQLite Fatal error: " . $self->dbh->errstr() . "\n";

    return 1;
}

sub user_exists_in_db {
    my ( $self, $user ) = @_;
    my $user_id;

    my $href = $self->dbh->selectall_hashref( "SELECT * FROM users", 'id' );
    foreach my $id ( keys %$href ) {
        my $user_info = decode_josn( $href->{$id}->{user_info} );
        $user_id = $id if ( $user_info->{username} eq $user );
    }

    return $user_id;
}

sub add_api_user_to_db {
    my ( $self, $user_name, $api_key ) = @_;

    my $dbh = $self->dbh;
    my $nb_inserted = $dbh->do( "INSERT INTO users (user_info) VALUES (?)", undef, encode_json( { username => $user_name, api_key => $api_key } ) );

    return $nb_inserted;
}

sub user_authorized {
    my ( $self, $user, $api_key ) = @_;

    my $user_id;

    my $href = $self->dbh->selectall_hashref( "SELECT * FROM users", 'id' );
    foreach my $id ( keys %$href ) {
        my $user_info = decode_josn( $href->{$id}->{user_info} );
        if ( $user_info->{username} eq $user && $user_info->{api_key} eq $api_key ) {
            $user_id = $id;
        }
    }

    return $user_id;
}

sub create_new_batch_job {
    my ( $self, $username ) = @_;

    my ( $batch_id, $creaton_time ) = $self->dbh->selectrow_array( "
               SELECT 
                    batch_id, 
                    batch_jobs.creation_time AS batch_creation_time 
               FROM 
                    test_results 
               JOIN batch_jobs 
                    ON batch_id=batch_jobs.id 
                    AND username=" . $self->dbh->quote( $username ) . " WHERE 
                    test_results.progress<>100
               LIMIT 1
               " );

    die "You can't create a new batch job, job:[$batch_id] started on:[$creaton_time] still running \n" if ( $batch_id );

    my ( $new_batch_id ) = $self->dbh->selectrow_array(
        "INSERT INTO batch_jobs (username) VALUES(" . $self->dbh->quote( $username ) . ") RETURNING id" );

    return $new_batch_id;
}

sub create_new_test {
    my ( $self, $domain, $test_params, $minutes_between_tests_with_same_params, $batch_id ) = @_;
    my $result;

    my $dbh = $self->dbh;

    $test_params->{domain} = $domain;
    my $js                             = JSON::PP->new->canonical;
    my $encoded_params                 = $js->encode( $test_params );
    my $test_params_deterministic_hash = md5_hex( $encoded_params );
    my $result_id;

    my $priority = $test_params->{priority};
    my $queue = $test_params->{queue};

	my ( $recent_id, $recent_hash_id ) = $dbh->selectrow_array(
		q[SELECT id, hash_id FROM test_results WHERE params_deterministic_hash = ? AND (CAST(strftime('%s', 'now') as integer) - CAST(strftime('%s', creation_time) as integer)) < ?],
		undef, $test_params_deterministic_hash, 60 * $minutes_between_tests_with_same_params,
	);

	if ( $recent_id ) {
		# A recent entry exists, so return its id
		if ( $recent_id > $self->config->force_hash_id_use_in_API_starting_from_id() ) {
			$result_id = $recent_hash_id;
		}
		else {
			$result_id = $recent_id;
		}
	}
	else {
		$dbh->do(
			q[INSERT INTO test_results (batch_id, priority, queue, params_deterministic_hash, params, domain, test_start_time, undelegated) VALUES (?, ?,?,?,?,?, datetime('now'),?)],
			undef,
			$batch_id,
			$priority,
			$queue,
			$test_params_deterministic_hash,
			$encoded_params,
			$test_params->{domain},
			($test_params->{nameservers})?(1):(0),
		);
		
		$dbh->do(q[UPDATE test_results SET hash_id = ? WHERE params_deterministic_hash = ?], undef, substr(md5_hex(time().rand()), 0, 16), $test_params_deterministic_hash);
		
		my ( $id, $hash_id ) = $dbh->selectrow_array(
			"SELECT id, hash_id FROM test_results WHERE params_deterministic_hash='$test_params_deterministic_hash' ORDER BY id DESC LIMIT 1" );
			
		if ( $id > $self->config->force_hash_id_use_in_API_starting_from_id() ) {
			$result_id = $hash_id;
		}
		else {
			$result_id = $id;
		}
	}

    return $result;
}

sub test_progress {
    my ( $self, $test_id, $progress ) = @_;

    my $id_field = $self->_get_allowed_id_field_name($test_id);

    my $dbh = $self->dbh;
    if ( $progress ) {
        if ($progress == 1) {
            $dbh->do( "UPDATE test_results SET progress=?, test_start_time=datetime('now') WHERE $id_field=? AND progress <> 100", undef, $progress, $test_id );
        }
        else {
            $dbh->do( "UPDATE test_results SET progress=? WHERE $id_field=? AND progress <> 100", undef, $progress, $test_id );
        }
    }

    my ( $result ) = $self->dbh->selectrow_array( "SELECT progress FROM test_results WHERE $id_field=?", undef, $test_id );

    return $result;
}

sub get_test_params {
    my ( $self, $test_id ) = @_;

    my $id_field = $self->_get_allowed_id_field_name($test_id);
    my ( $params_json ) = $self->dbh->selectrow_array( "SELECT params FROM test_results WHERE $id_field=?", undef, $test_id );

    my $result;
    eval {
        $result = decode_json( $params_json );
    };
    
    warn "decoding of params_json failed (testi_id: [$test_id]):".Dumper($params_json) if $@;

    return $result;
}

sub test_results {
    my ( $self, $test_id, $new_results ) = @_;

    my $id_field = $self->_get_allowed_id_field_name($test_id);
    
    if ( $new_results ) {
        $self->dbh->do( qq[UPDATE test_results SET progress=100, test_end_time=datetime('now'), results = ? WHERE $id_field=? AND progress < 100],
            undef, $new_results, $test_id );
    }

    my $result;
    my ( $hrefs ) = $self->dbh->selectall_hashref( "SELECT id, hash_id, datetime(creation_time,'localtime') AS creation_time, params, results FROM test_results WHERE $id_field=?", $id_field, undef, $test_id );
    $result            = $hrefs->{$test_id};
    $result->{params}  = decode_json( $result->{params} );
    $result->{results} = decode_json( $result->{results} );

    return $result;
}

sub get_test_history {
    my ( $self, $p ) = @_;

    my @results;

    my $undelegated = "";
    if ($p->{filter} eq "undelegated") {
        $undelegated = "AND (params->'nameservers') IS NOT NULL";
    } elsif ($p->{filter} eq "delegated") {
        $undelegated = "AND (params->'nameservers') IS NULL";
    }

    my $quoted_domain = $self->dbh->quote( $p->{frontend_params}->{domain} );
    $quoted_domain =~ s/'/"/g;
    my $query = "SELECT
                    id,
                    creation_time,
                    params
                 FROM
                    test_results
                 WHERE
                    params like '\%\"domain\":$quoted_domain\%'
                    $undelegated
                 ORDER BY id DESC LIMIT $p->{limit} OFFSET $p->{offset} ";
    my $sth1 = $self->dbh->prepare( $query );
    $sth1->execute;
    while ( my $h = $sth1->fetchrow_hashref ) {
        push( @results,
            { id => $h->{id}, creation_time => $h->{creation_time} } );
    }
    $sth1->finish;

    return \@results;
}

sub add_batch_job {
    my ( $self, $params ) = @_;
}

sub build_process_unfinished_tests_select_query {
     my ( $self ) = @_;
     
     if ($self->config->lock_on_queue()) {
          return "
               SELECT hash_id, results, nb_retries
               FROM test_results 
               WHERE test_start_time < DATETIME('now', '-".$self->config->MaxZonemasterExecutionTime()." seconds')
               AND nb_retries <= ".$self->config->maximal_number_of_retries()." 
               AND progress > 0
               AND progress < 100
               AND queue=".$self->config->lock_on_queue();
     }
     else {
          return "
               SELECT hash_id, results, nb_retries
               FROM test_results 
               WHERE test_start_time < DATETIME('now', '-".$self->config->MaxZonemasterExecutionTime()." seconds')
               AND nb_retries <= ".$self->config->maximal_number_of_retries()." 
               AND progress > 0
               AND progress < 100";
     }
}

sub process_unfinished_tests_give_up {
     my ( $self, $result, $hash_id ) = @_;

     $self->dbh->do("UPDATE test_results SET progress = 100, test_end_time = DATETIME('now'), results = ? WHERE hash_id=?", undef, encode_json($result), $hash_id);
}

sub schedule_for_retry {
    my ( $self, $hash_id ) = @_;

    $self->dbh->do("UPDATE test_results SET nb_retries = nb_retries + 1, progress = 0, test_start_time = DATETIME('now') WHERE hash_id=?", undef, $hash_id);
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;
