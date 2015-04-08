package Zonemaster::WebBackend::DB::MySQL;

our $VERSION = '1.0.2';

use Moose;
use 5.14.2;

use DBI qw(:utils);
use JSON;
use Digest::MD5 qw(md5_hex);

use Zonemaster::WebBackend::Config;

with 'Zonemaster::WebBackend::DB';

my $connection_string = Zonemaster::WebBackend::Config->DB_connection_string( 'mysql' );

has 'dbh' => (
    is  => 'ro',
    isa => 'DBI::db',
    default =>
      sub { DBI->connect( $connection_string, "zonemaster", "zonemaster", { RaiseError => 1, AutoCommit => 1 } ) },
);

sub user_exists_in_db {
    my ( $self, $user ) = @_;

    my ( $id ) = $self->dbh->selectrow_array( "SELECT id FROM users WHERE username = ?", undef, $user );

    return $id;
}

sub add_api_user_to_db {
    my ( $self, $user_info ) = @_;

    my $nb_inserted = $self->dbh->do(
        "INSERT INTO users (user_info, username, api_key) VALUES (?,?,?)",
        undef,
        encode_json( $user_info ),
        $user_info->{username},
        $user_info->{api_key},
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
    my ( $self, $domain, $test_params, $minutes_between_tests_with_same_params, $priority, $batch_id ) = @_;
    my $result;

    $test_params->{domain} = $domain;
    my $js                             = JSON->new->canonical;
    my $encoded_params                 = $js->encode( $test_params );
    my $test_params_deterministic_hash = md5_hex( $encoded_params );
    my $result_id;

    eval {
        $self->dbh->do( q[LOCK TABLES test_results WRITE] );
        my ( $recent_id ) = $self->dbh->selectrow_array(
            q[
SELECT id FROM test_results WHERE params_deterministic_hash = ? AND (TO_SECONDS(NOW()) - TO_SECONDS(creation_time)) < ?
],
            undef, $test_params_deterministic_hash, 60 * $minutes_between_tests_with_same_params,
        );

        if ( $recent_id ) {
            $result_id = $recent_id;  # A recent entry exists, so return its id
        }
        else {
            $self->dbh->do(
                q[
            INSERT INTO test_results (batch_id, priority, params_deterministic_hash, params, domain) VALUES (?,?,?,?,?)
        ],
                undef,
                $batch_id,
                $priority,
                $test_params_deterministic_hash,
                $encoded_params,
                $test_params->{domain},
            );
            $result_id = $self->dbh->{mysql_insertid};
        }
    };
    $self->dbh->do( q[UNLOCK TABLES] );

    return $result_id;
}

sub test_progress {
    my ( $self, $test_id, $progress ) = @_;

    $self->dbh->do( "UPDATE test_results SET progress=? WHERE id=?", undef, $progress, $test_id )
      if ( $progress );

    my ( $result ) = $self->dbh->selectrow_array( "SELECT progress FROM test_results WHERE id=?", undef, $test_id );

    return $result;
}

sub get_test_params {
    my ( $self, $test_id ) = @_;

    my ( $params_json ) = $self->dbh->selectrow_array( "SELECT params FROM test_results WHERE id=?", undef, $test_id );

    return decode_json( $params_json );
}

sub test_results {
    my ( $self, $test_id, $new_results ) = @_;

    if ( $new_results ) {
        $self->dbh->do( q[UPDATE test_results SET progress=100, test_end_time=NOW(), results = ? WHERE id=?],
            undef, $new_results, $test_id );
    }

    my $result;
    my ( $hrefs ) = $self->dbh->selectall_hashref( "SELECT * FROM test_results WHERE id=?", 'id', undef, $test_id );
    $result            = $hrefs->{$test_id};
    $result->{params}  = decode_json( $result->{params} );
    $result->{results} = decode_json( $result->{results} );

    return $result;
}

sub get_test_history {
    my ( $self, $p ) = @_;

    my @results;
    my $sth = $self->dbh->prepare(
q[SELECT id, creation_time, params, results FROM test_results WHERE domain = ? ORDER BY id DESC LIMIT ? OFFSET ?]
    );
    $sth->execute( $p->{frontend_params}{domain}, $p->{limit}, $p->{offset} );
    while ( my $h = $sth->fetchrow_hashref ) {
        my $critical = ( grep { $_->level eq 'CRITICAL' } @{ $h->{results} } );
        my $error    = ( grep { $_->level eq 'ERROR' } @{ $h->{results} } );
        my $warning  = ( grep { $_->level eq 'WARNING' } @{ $h->{results} } );

        # More important overwrites
        my $overall;
        $overall = 'warning'  if $warning;
        $overall = 'error'    if $error;
        $overall = 'critical' if $critical;

        push(
            @results,
            {
                id               => $h->{id},
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
