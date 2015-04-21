package Zonemaster::WebBackend::DB::PostgreSQL;

our $VERSION = '1.0.1';

use Moose;
use 5.14.2;

use DBI qw(:utils);
use JSON;
use Digest::MD5 qw(md5_hex);
use Encode;

use Zonemaster::WebBackend::DB;
use Zonemaster::WebBackend::Config;

with 'Zonemaster::WebBackend::DB';

my $connection_string = Zonemaster::WebBackend::Config->DB_connection_string('postgresql');

has 'dbh' => (
    is  => 'ro',
    isa => 'DBI::db',
    default =>
      sub { DBI->connect( $connection_string, Zonemaster::WebBackend::Config::DB_user(), Zonemaster::WebBackend::Config::DB_password(), { RaiseError => 1, AutoCommit => 1 } ) },
);

sub user_exists_in_db {
    my ( $self, $user ) = @_;

    my ( $id ) =
      $self->dbh->selectrow_array( "SELECT id FROM users WHERE user_info->>'username'=" . $self->dbh->quote( $user ) );

    return $id;
}

sub add_api_user_to_db {
    my ( $self, $user_info ) = @_;

    my $nb_inserted =
      $self->dbh->do( "INSERT INTO users (user_info) VALUES(" . $self->dbh->quote( encode_json( $user_info ) ) . ")" );

    return $nb_inserted;
}

sub user_authorized {
    my ( $self, $user, $api_key ) = @_;

    my $id =
      $self->dbh->selectrow_array( "SELECT id FROM users WHERE user_info->>'username'="
          . $self->dbh->quote( $user )
          . " AND user_info->>'api_key'="
          . $self->dbh->quote( $api_key ) );

    return $id;
}

sub test_progress {
    my ( $self, $test_id, $progress ) = @_;

    $self->dbh->do( "UPDATE test_results SET progress=$progress WHERE id=" . $self->dbh->quote( $test_id ) )
      if ( $progress );

    my ( $result ) =
      $self->dbh->selectrow_array( "SELECT progress FROM test_results WHERE id=" . $self->dbh->quote( $test_id ) );

    return $result;
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

    die "You can't create a new batch job, job:[$batch_id] started on:[$creaton_time] still running " if ( $batch_id );

    my ( $new_batch_id ) = $self->dbh->selectrow_array(
        "INSERT INTO batch_jobs (username) VALUES(" . $self->dbh->quote( $username ) . ") RETURNING id" );

    return $new_batch_id;
}

sub create_new_test {
    my ( $self, $domain, $test_params, $minutes_between_tests_with_same_params, $priority, $batch_id ) = @_;
    my $result;

    $test_params->{domain} = $domain;
    my $js = JSON->new;
    $js->canonical( 1 );
    my $encoded_params                 = $js->encode( $test_params );
    my $test_params_deterministic_hash = md5_hex( encode_utf8( $encoded_params ) );

    my $query =
        "INSERT INTO test_results (batch_id, priority, params_deterministic_hash, params) SELECT "
      . $self->dbh->quote( $batch_id ) . ", "
      . $self->dbh->quote( 5 ) . ", "
      . $self->dbh->quote( $test_params_deterministic_hash ) . ", "
      . $self->dbh->quote( $encoded_params )
      . " WHERE NOT EXISTS (SELECT * FROM test_results WHERE params_deterministic_hash='$test_params_deterministic_hash' AND creation_time > NOW()-'$minutes_between_tests_with_same_params minutes'::interval)";

    my $nb_inserted = $self->dbh->do( $query );

    ( $result ) = $self->dbh->selectrow_array(
        "SELECT MAX(id) AS id FROM test_results WHERE params_deterministic_hash='$test_params_deterministic_hash'" );

    return $result;
}

sub get_test_params {
    my ( $self, $test_id ) = @_;

    my $result;

    my ( $params_json ) =
      $self->dbh->selectrow_array( "SELECT params FROM test_results WHERE id=" . $self->dbh->quote( $test_id ) );
    eval { $result = decode_json( encode_utf8( $params_json ) ); };
    die $@ if $@;

    return $result;
}

sub test_results {
    my ( $self, $test_id, $results ) = @_;

    $self->dbh->do( "UPDATE test_results SET progress=100, test_end_time=NOW(), results = "
          . $self->dbh->quote( $results )
          . " WHERE id="
          . $self->dbh->quote( $test_id ) )
      if ( $results );

    my $result;
    eval {
        my ( $hrefs ) =
          $self->dbh->selectall_hashref( "SELECT * FROM test_results WHERE id=" . $self->dbh->quote( $test_id ), 'id' );
        $result            = $hrefs->{$test_id};
        $result->{params}  = decode_json( encode_utf8( $result->{params} ) );
        $result->{results} = decode_json( encode_utf8( $result->{results} ) );
    };
    die $@ if $@;

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
			creation_time, 
			params->>'advanced_options' AS advanced_options 
		FROM test_results 
		WHERE params->>'domain'=" . $self->dbh->quote( $p->{frontend_params}->{domain} ) . " $undelegated 
		ORDER BY id DESC 
		OFFSET $p->{offset} LIMIT $p->{limit}";
    my $sth1 = $self->dbh->prepare( $query );
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
                id               => $h->{id},
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
