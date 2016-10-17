package Zonemaster::WebBackend::DB::PostgreSQL;

our $VERSION = '1.0.7';

use Moose;
use 5.14.2;

use DBI qw(:utils);
use JSON::PP;
use Digest::MD5 qw(md5_hex);
use Encode;

use Zonemaster::WebBackend::DB;
use Zonemaster::WebBackend::Config;

with 'Zonemaster::WebBackend::DB';

has 'dbhandle' => (
    is  => 'rw',
    isa => 'DBI::db',
);

my $connection_string   = Zonemaster::WebBackend::Config->DB_connection_string( 'postgresql' );
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

    my $dbh = $self->dbh;
    my ( $id ) = $dbh->selectrow_array( "SELECT id FROM users WHERE user_info->>'username'=?", undef, $user );

    return $id;
}

sub add_api_user_to_db {
    my ( $self, $user_name, $api_key ) = @_;

    my $dbh = $self->dbh;
    my $nb_inserted = $dbh->do( "INSERT INTO users (user_info) VALUES (?)", undef, encode_json( { username => $user_name, api_key => $api_key } ) );

    return $nb_inserted;
}

sub user_authorized {
    my ( $self, $user, $api_key ) = @_;

    my $dbh = $self->dbh;
    my $id =
      $dbh->selectrow_array( "SELECT id FROM users WHERE user_info->>'username'=? AND user_info->>'api_key'=?",
        undef, $user, $api_key );

    return $id;
}

sub test_progress {
    my ( $self, $test_id, $progress ) = @_;

	my $id_field = $self->_get_allowed_id_field_name($test_id);
    my $dbh = $self->dbh;
    $dbh->do( "UPDATE test_results SET progress=$progress WHERE $id_field=?", undef, $test_id ) if ( $progress );
	
    my ( $result ) = $dbh->selectrow_array( "SELECT progress FROM test_results WHERE $id_field=?", undef, $test_id );

    return $result;
}

sub create_new_batch_job {
    my ( $self, $username ) = @_;

    my $dbh = $self->dbh;
    my ( $batch_id, $creation_time ) = $dbh->selectrow_array( "
			SELECT 
				batch_id, 
				batch_jobs.creation_time AS batch_creation_time 
			FROM 
				test_results 
			JOIN batch_jobs 
				ON batch_id=batch_jobs.id 
				AND username=? WHERE 
				test_results.progress<>100
			LIMIT 1
			", undef, $username );

    die "You can't create a new batch job, job:[$batch_id] started on:[$creation_time] still running " if ( $batch_id );

    my ( $new_batch_id ) =
      $dbh->selectrow_array( "INSERT INTO batch_jobs (username) VALUES (?) RETURNING id", undef, $username );

    return $new_batch_id;
}

sub create_new_test {
    my ( $self, $domain, $test_params, $minutes_between_tests_with_same_params, $priority, $batch_id ) = @_;
    my $result;
    my $dbh = $self->dbh;

    $test_params->{domain} = $domain;
    my $js = JSON->new;
    $js->canonical( 1 );
    my $encoded_params                 = $js->encode( $test_params );
    my $test_params_deterministic_hash = md5_hex( encode_utf8( $encoded_params ) );

    my $query =
        "INSERT INTO test_results (batch_id, priority, params_deterministic_hash, params) SELECT "
      . $dbh->quote( $batch_id ) . ", "
      . $dbh->quote( 5 ) . ", "
      . $dbh->quote( $test_params_deterministic_hash ) . ", "
      . $dbh->quote( $encoded_params )
      . " WHERE NOT EXISTS (SELECT * FROM test_results WHERE params_deterministic_hash='$test_params_deterministic_hash' AND creation_time > NOW()-'$minutes_between_tests_with_same_params minutes'::interval)";

    my $nb_inserted = $dbh->do( $query );

    my ( $id, $hash_id ) = $dbh->selectrow_array(
        "SELECT id, hash_id FROM test_results WHERE params_deterministic_hash='$test_params_deterministic_hash' ORDER BY id DESC LIMIT 1" );
        
    if ( $id > Zonemaster::WebBackend::Config->force_hash_id_use_in_API_starting_from_id() ) {
		$result = $hash_id;
    }
    else {
		$result = $id;
    }

    return $result;
}

sub get_test_params {
    my ( $self, $test_id ) = @_;

    my $result;

    my $dbh = $self->dbh;
	my $id_field = $self->_get_allowed_id_field_name($test_id);
    my ( $params_json ) = $dbh->selectrow_array( "SELECT params FROM test_results WHERE $id_field=?", undef, $test_id );
    eval { $result = decode_json( encode_utf8( $params_json ) ); };
    die $@ if $@;

    return $result;
}

sub test_results {
    my ( $self, $test_id, $results ) = @_;

    my $dbh = $self->dbh;
	my $id_field = $self->_get_allowed_id_field_name($test_id);
    $dbh->do( "UPDATE test_results SET progress=100, test_end_time=NOW(), results = ? WHERE $id_field=?",
        undef, $results, $test_id )
      if ( $results );

    my $result;
    eval {
        my ( $hrefs ) = $dbh->selectall_hashref( "SELECT id, hash_id, creation_time at time zone current_setting('TIMEZONE') at time zone 'UTC' as creation_time, params, results FROM test_results WHERE $id_field=?", $id_field, undef, $test_id );
        $result            = $hrefs->{$test_id};
        $result->{params}  = decode_json( encode_utf8( $result->{params} ) );
        $result->{results} = decode_json( encode_utf8( $result->{results} ) );
    };
    die $@ if $@;

    return $result;
}

sub get_test_history {
    my ( $self, $p ) = @_;

    my $dbh = $self->dbh;
    
    $p->{offset} //= 0;
    $p->{limit} //= 200;

    my $use_hash_id_from_id = Zonemaster::WebBackend::Config->force_hash_id_use_in_API_starting_from_id();
    my $undelegated =
        ( defined $p->{frontend_params}->{nameservers} )
      ? ( "AND (params->'nameservers') IS NOT NULL" )
      : ( "AND (params->'nameservers') IS NULL" );

    my @results;
    my $query = "
		SELECT 
			(SELECT count(*) FROM (SELECT json_array_elements(results) AS result) AS t1 WHERE result->>'level'='CRITICAL') AS nb_critical,
			(SELECT count(*) FROM (SELECT json_array_elements(results) AS result) AS t1 WHERE result->>'level'='ERROR') AS nb_error,
			(SELECT count(*) FROM (SELECT json_array_elements(results) AS result) AS t1 WHERE result->>'level'='WARNING') AS nb_warning,
			id,
			hash_id,
			creation_time at time zone current_setting('TIMEZONE') at time zone 'UTC' as creation_time, 
			params->>'advanced_options' AS advanced_options 
		FROM test_results 
		WHERE params->>'domain'=" . $dbh->quote( $p->{frontend_params}->{domain} ) . " $undelegated 
		ORDER BY id DESC 
		OFFSET $p->{offset} LIMIT $p->{limit}";
	my $sth1 = $dbh->prepare( $query );
	$sth1->execute;
	while ( my $h = $sth1->fetchrow_hashref ) {
		my $overall_result = 'ok';
		if ( $h->{nb_critical} ) {
			$overall_result = 'critical';
		}
		elsif ( $h->{nb_error} ) {
			$overall_result = 'error';
		}
		elsif ( $h->{nb_warning} ) {
			$overall_result = 'warning';
		}

		push(
			@results,
			{
				id               => ($h->{id} > $use_hash_id_from_id)?($h->{hash_id}):($h->{id}),
				creation_time    => $h->{creation_time},
				advanced_options => $h->{advanced_options},
				overall_result   => $overall_result
			}
		);
	}

	return \@results;
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;
