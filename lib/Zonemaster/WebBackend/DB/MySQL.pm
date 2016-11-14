package Zonemaster::WebBackend::DB::MySQL;

our $VERSION = '1.0.7';

use Moose;
use 5.14.2;

use DBI qw(:utils);
use JSON::PP;
use Digest::MD5 qw(md5_hex);

use Zonemaster::WebBackend::Config;

with 'Zonemaster::WebBackend::DB';

has 'dbhandle' => (
    is  => 'rw',
    isa => 'DBI::db',
);

my $connection_string   = Zonemaster::WebBackend::Config->DB_connection_string( 'mysql' );
my $connection_args     = { RaiseError => 1, AutoCommit => 1 };
my $connection_user     = Zonemaster::WebBackend::Config->DB_user();
my $connection_password = Zonemaster::WebBackend::Config->DB_password();

sub dbh {
    my ( $self ) = @_;
    my $dbh = $self->dbhandle;

    if ( $dbh and $dbh->ping ) {
        return $dbh;
    }
    else {
        $dbh = DBI->connect( $connection_string, $connection_user, $connection_password, $connection_args );
        $dbh->{AutoInactiveDestroy} = 1;
        $self->dbhandle( $dbh );
        return $dbh;
    }
}

sub user_exists_in_db {
    my ( $self, $user ) = @_;

    my ( $id ) = $self->dbh->selectrow_array( "SELECT id FROM users WHERE username = ?", undef, $user );

    return $id;
}

sub add_api_user_to_db {
    my ( $self, $user_name, $api_key  ) = @_;

    my $nb_inserted = $self->dbh->do(
        "INSERT INTO users (user_info, username, api_key) VALUES (?,?,?)",
        undef,
        'NULL',
        $user_name,
        $api_key,
    );

    return $nb_inserted;
}

sub user_authorized {
    my ( $self, $user, $api_key ) = @_;

    my ( $id ) =
      $self->dbh->selectrow_array( q[SELECT id FROM users WHERE username = ? AND api_key = ?], undef, $user, $api_key );

    return $id;
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
				AND username=?
            WHERE 
				test_results.progress<>100
			LIMIT 1
			", undef, $username );

    die "You can't create a new batch job, job:[$batch_id] started on:[$creaton_time] still running " if ( $batch_id );

    $self->dbh->do( "INSERT INTO batch_jobs (username) VALUES(?)", undef, $username );
    my ( $new_batch_id ) = $self->dbh->{mysql_insertid};

    return $new_batch_id;
}

sub create_new_test {
    my ( $self, $domain, $test_params, $minutes_between_tests_with_same_params, $batch_id ) = @_;
    my $result;
    my $dbh = $self->dbh;

    my $priority = 10;
    $priority = $test_params->{priority} if (defined $test_params->{priority});
    
    my $queue = 0;
    $queue = $test_params->{queue} if (defined $test_params->{queue});

    $test_params->{domain} = $domain;
    my $js                             = JSON->new->canonical;
    my $encoded_params                 = $js->encode( $test_params );
    my $test_params_deterministic_hash = md5_hex( $encoded_params );
    my $result_id;

    eval {
        $dbh->do( q[LOCK TABLES test_results WRITE] );
        my ( $recent_id, $recent_hash_id ) = $dbh->selectrow_array(
            q[
SELECT id, hash_id FROM test_results WHERE params_deterministic_hash = ? AND (TO_SECONDS(NOW()) - TO_SECONDS(creation_time)) < ?
],
            undef, $test_params_deterministic_hash, 60 * $minutes_between_tests_with_same_params,
        );

        if ( $recent_id ) {
            # A recent entry exists, so return its id
            if ( $recent_id > Zonemaster::WebBackend::Config->force_hash_id_use_in_API_starting_from_id() ) {
				$result_id = $recent_hash_id;
			}
			else {
				$result_id = $recent_id;
			}
        }
        else {
            $dbh->do(
                q[
            INSERT INTO test_results (batch_id, priority, queue, params_deterministic_hash, params, domain, test_start_time, undelegated) VALUES (?,?,?,?,?, NOW(),?)
        ],
                undef,
                $batch_id,
                $priority,
                $queue,
                $test_params_deterministic_hash,
                $encoded_params,
                $test_params->{domain},
                ($test_params->{nameservers})?(1):(0),
            );
            
			my ( $id, $hash_id ) = $dbh->selectrow_array(
				"SELECT id, hash_id FROM test_results WHERE params_deterministic_hash='$test_params_deterministic_hash' ORDER BY id DESC LIMIT 1" );
				
			if ( $id > Zonemaster::WebBackend::Config->force_hash_id_use_in_API_starting_from_id() ) {
				$result_id = $hash_id;
			}
			else {
				$result_id = $id;
			}
        }
    };
    $dbh->do( q[UNLOCK TABLES] );

    return $result_id;
}

sub test_progress {
    my ( $self, $test_id, $progress ) = @_;

	my $id_field = $self->_get_allowed_id_field_name($test_id);

	my $dbh = $self->dbh;
	$dbh->do( "UPDATE test_results SET progress=?,test_end_time=NOW() WHERE $id_field=?", undef, $progress, $test_id )
      if ( $progress );

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
    
    return decode_json( $params_json );
}

sub test_results {
    my ( $self, $test_id, $new_results ) = @_;

	my $id_field = $self->_get_allowed_id_field_name($test_id);
	
    if ( $new_results ) {
        $self->dbh->do( qq[UPDATE test_results SET progress=100, test_end_time=NOW(), results = ? WHERE $id_field=?],
            undef, $new_results, $test_id );
    }

    my $result;
    my ( $hrefs ) = $self->dbh->selectall_hashref( "SELECT id, hash_id, CONVERT_TZ(`creation_time`, \@\@session.time_zone, '+00:00') AS creation_time, params, results FROM test_results WHERE $id_field=?", $id_field, undef, $test_id );
    $result            = $hrefs->{$test_id};
    $result->{params}  = decode_json( $result->{params} );
    $result->{results} = decode_json( $result->{results} );

    return $result;
}

sub get_test_history {
    my ( $self, $p ) = @_;

    my @results;
    
    my $use_hash_id_from_id = Zonemaster::WebBackend::Config->force_hash_id_use_in_API_starting_from_id();
    
    my $sth = $self->dbh->prepare(
			q[SELECT 
				id, 
				hash_id, 
				CONVERT_TZ(`creation_time`, @@session.time_zone, '+00:00') AS creation_time, 
				params, 
				results 
			FROM 
				test_results 
			WHERE 
				domain = ? 
				AND undelegated = ? 
			ORDER BY id DESC 
			LIMIT ? OFFSET ?]
    );
    $sth->execute( $p->{frontend_params}{domain}, ($p->{frontend_params}{nameservers})?1:0, $p->{limit}, $p->{offset} );
    while ( my $h = $sth->fetchrow_hashref ) {
        $h->{results} = decode_json($h->{results}) if $h->{results};
        $h->{params} = decode_json($h->{params}) if $h->{params};
        my $critical = ( grep { $_->{level} eq 'CRITICAL' } @{ $h->{results} } );
        my $error    = ( grep { $_->{level} eq 'ERROR' } @{ $h->{results} } );
        my $warning  = ( grep { $_->{level} eq 'WARNING' } @{ $h->{results} } );

        # More important overwrites
        my $overall = 'INFO';
        $overall = 'warning'  if $warning;
        $overall = 'error'    if $error;
        $overall = 'critical' if $critical;

        push(
            @results,
            {
                id               => ($h->{id} > $use_hash_id_from_id)?($h->{hash_id}):($h->{id}),
                creation_time    => $h->{creation_time},
                advanced_options => $h->{params}{advanced_options},
                overall_result   => $overall,
            }
        );
    }

    return \@results;
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;
