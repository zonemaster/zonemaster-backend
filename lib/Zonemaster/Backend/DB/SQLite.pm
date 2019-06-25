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
					batch_id integer NULL,
					creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
					test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
					test_end_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
					priority integer DEFAULT 10,
					queue integer DEFAULT 0,
					progress integer DEFAULT 0,
					params_deterministic_hash character varying(32),
					params text NOT NULL,
					results text DEFAULT NULL
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

    my $priority = 10;
    $priority = $test_params->{priority} if (defined $test_params->{priority});
    
    my $queue = 0;
    $queue = $test_params->{queue} if (defined $test_params->{queue});

    $test_params->{domain} = $domain;
    my $js = JSON::PP->new;
    $js->canonical( 1 );
    my $encoded_params                 = $js->encode( $test_params );
    my $test_params_deterministic_hash = md5_hex( $encoded_params );

    my $query =
        "INSERT INTO test_results (batch_id, priority, queue, params_deterministic_hash, params) SELECT "
      . $self->dbh->quote( $batch_id ) . ", "
      . $self->dbh->quote( $priority ) . ", "
      . $self->dbh->quote( $queue ) . ", "
      . $self->dbh->quote( $test_params_deterministic_hash ) . ", "
      . $self->dbh->quote( $encoded_params )
      . " WHERE NOT EXISTS (SELECT * FROM test_results WHERE params_deterministic_hash='$test_params_deterministic_hash' AND creation_time > datetime('now', '-$minutes_between_tests_with_same_params minute'))";

    my $nb_inserted = $self->dbh->do( $query );

    ( $result ) = $self->dbh->selectrow_array(
        "SELECT MAX(id) AS id FROM test_results WHERE params_deterministic_hash='$test_params_deterministic_hash'" );

    return $result;
}

sub test_progress {
    my ( $self, $test_id, $progress ) = @_;

    $self->dbh->do( "UPDATE test_results SET progress=$progress WHERE id=$test_id" ) if ( $progress );

    my ( $result ) = $self->dbh->selectrow_array( "SELECT progress FROM test_results WHERE id=$test_id" );

    return $result;
}

sub get_test_params {
    my ( $self, $test_id ) = @_;

    my $result;

    my ( $params_json ) = $self->dbh->selectrow_array( "SELECT params FROM test_results WHERE id=$test_id" );
    eval { $result = decode_json( $params_json ); };
    die "$@ \n" if $@;

    return $result;
}

sub test_results {
    my ( $self, $test_id, $results ) = @_;

    $self->dbh->do( "UPDATE test_results SET progress=100, test_end_time=datetime('now'), results = "
          . $self->dbh->quote( $results )
          . " WHERE id=$test_id " )
      if ( $results );

    my $result;
    eval {
        my ( $hrefs ) = $self->dbh->selectall_hashref( "SELECT * FROM test_results WHERE id=$test_id", 'id' );
        $result            = $hrefs->{$test_id};
        $result->{params}  = decode_json( $result->{params} );
        $result->{results} = decode_json( $result->{results} );
    };
    die "$@ \n" if $@;

    return $result;
}

sub get_test_request {
    my ( $self ) = @_;

    my ( $id ) = $self->dbh->selectrow_array(
        q[ SELECT id FROM test_results WHERE progress=0 ORDER BY priority ASC, id ASC LIMIT 1 ] );
    $self->dbh->do( q[UPDATE test_results SET progress=1 WHERE id=?], undef, $id );

    return $id;
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

no Moose;
__PACKAGE__->meta()->make_immutable();

1;
