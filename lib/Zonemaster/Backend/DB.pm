package Zonemaster::Backend::DB;

our $VERSION = '1.2.0';

use Moose::Role;

use 5.14.2;

use Digest::MD5 qw(md5_hex);
use Encode;
use JSON::PP;
use Log::Any qw( $log );

use Zonemaster::Engine::Profile;
use Zonemaster::Backend::Errors;

requires qw(
  add_batch_job
  create_db
  create_new_test
  from_config
  get_test_history
  last_insert_id
  process_unfinished_tests_give_up
  recent_test_hash_id
  select_unfinished_tests
  test_progress
  test_results
  get_relative_start_time
);

has 'data_source_name' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'user' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'password' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'dbhandle' => (
    is       => 'rw',
    isa      => 'DBI::db',
    required => 1,
);

=head2 get_db_class

Get the database adapter class for the given database type.

Throws and exception if the database adapter class cannot be loaded.

=cut

sub get_db_class {
    my ( $class, $db_type ) = @_;

    my $db_class = "Zonemaster::Backend::DB::$db_type";

    require( "$db_class.pm" =~ s{::}{/}gr );
    $db_class->import();

    return $db_class;
}

sub dbh {
    my ( $self ) = @_;

    if ( !$self->dbhandle->ping ) {
        my $dbh = $self->_new_dbh(    #
            $self->data_source_name,
            $self->user,
            $self->password,
        );

        $self->dbhandle( $dbh );
    }

    return $self->dbhandle;
}

sub user_exists {
    my ( $self, $user ) = @_;

    die Zonemaster::Backend::Error::Internal->new( reason => "username not provided to the method user_exists")
        unless ( $user );

    return $self->user_exists_in_db( $user );
}

sub add_api_user {
    my ( $self, $username, $api_key ) = @_;

    die Zonemaster::Backend::Error::Internal->new( reason => "username or api_key not provided to the method add_api_user")
        unless ( $username && $api_key );

    die Zonemaster::Backend::Error::Conflict->new( message => 'User already exists', data => { username => $username } )
        if ( $self->user_exists( $username ) );

    my $result = $self->add_api_user_to_db( $username, $api_key );

    die Zonemaster::Backend::Error::Internal->new( reason => "add_api_user_to_db not successful")
        unless ( $result );

    return $result;
}

# Standard SQL, can be here
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
                ON batch_id = batch_jobs.id
                AND username = ?
            WHERE
                test_results.progress <> 100
            LIMIT 1
            ", undef, $username );

    die Zonemaster::Backend::Error::Conflict->new( message => 'Batch job still running', data => { batch_id => $batch_id, creation_time => $creation_time } )
        if ( $batch_id );

    $dbh->do( "INSERT INTO batch_jobs (username) VALUES (?)", undef, $username );
    my ( $new_batch_id ) = $self->last_insert_id( $dbh, "batch_jobs" );

    return $new_batch_id;
}

# Standard SQL, can be here
sub user_exists_in_db {
    my ( $self, $user ) = @_;

    my $dbh = $self->dbh;
    my ( $id ) = $dbh->selectrow_array(
        "SELECT id FROM users WHERE username = ?",
        undef,
        $user
    );

    return $id;
}

# Standard SQL, can be here
sub add_api_user_to_db {
    my ( $self, $user_name, $api_key  ) = @_;

    my $dbh = $self->dbh;
    my $nb_inserted = $dbh->do(
        "INSERT INTO users (username, api_key) VALUES (?,?)",
        undef,
        $user_name,
        $api_key,
    );

    return $nb_inserted;
}

# Standard SQL, can be here
sub user_authorized {
    my ( $self, $user, $api_key ) = @_;

    my $dbh = $self->dbh;
    my ( $id ) = $dbh->selectrow_array(
        "SELECT id FROM users WHERE username = ? AND api_key = ?",
        undef,
        $user,
        $api_key
    );

    return $id;
}

# Standard SQL, can be here
sub get_test_request {
    my ( $self, $queue_label ) = @_;

    my $result_id;
    my $dbh = $self->dbh;

    my ( $id, $hash_id );
    if ( defined $queue_label ) {
        ( $id, $hash_id ) = $dbh->selectrow_array( qq[ SELECT id, hash_id FROM test_results WHERE progress=0 AND queue=? ORDER BY priority DESC, id ASC LIMIT 1 ], undef, $queue_label );
    }
    else {
        ( $id, $hash_id ) = $dbh->selectrow_array( q[ SELECT id, hash_id FROM test_results WHERE progress=0 ORDER BY priority DESC, id ASC LIMIT 1 ] );
    }

    if ($id) {
        $dbh->do( q[UPDATE test_results SET progress=1 WHERE id=?], undef, $id );
        $result_id = $hash_id;
    }
    return $result_id;
}

# Standard SQL, can be here
sub get_test_params {
    my ( $self, $test_id ) = @_;

    my $dbh = $self->dbh;
    my ( $params_json ) = $dbh->selectrow_array( "SELECT params FROM test_results WHERE hash_id = ?", undef, $test_id );

    die Zonemaster::Backend::Error::ResourceNotFound->new( message => "Test not found", data => { test_id => $test_id } )
        unless defined $params_json;

    my $result;
    eval {
        # TODO: do we use "encode_utf8" as this was the case in PostgreSQL
        #       (see commit diff)
        $result = decode_json( $params_json );
    };

    die Zonemaster::Backend::Error::JsonError->new( reason => "$@", data => { test_id => $test_id } )
        if $@;

    return $result;
}

# Standatd SQL, can be here
sub get_batch_job_result {
    my ( $self, $batch_id ) = @_;

    my $dbh = $self->dbh;

    my %result;
    $result{nb_running} = 0;
    $result{nb_finished} = 0;

    my $query = "
        SELECT hash_id, progress
        FROM test_results
        WHERE batch_id=?";

    my $sth1 = $dbh->prepare( $query );
    $sth1->execute( $batch_id );
    while ( my $h = $sth1->fetchrow_hashref ) {
        if ( $h->{progress} eq '100' ) {
            $result{nb_finished}++;
            push(@{$result{finished_test_ids}}, $h->{hash_id});
        }
        else {
            $result{nb_running}++;
        }
    }

    return \%result;
}

sub process_unfinished_tests {
    my ( $self, $queue_label, $test_run_timeout, $test_run_max_retries ) = @_;

    my $sth1 = $self->select_unfinished_tests(    #
        $queue_label,
        $test_run_timeout,
        $test_run_max_retries,
    );

    while ( my $h = $sth1->fetchrow_hashref ) {
        if ( $h->{nb_retries} < $test_run_max_retries ) {
            $self->schedule_for_retry($h->{hash_id});
        }
        else {
            $self->force_end_test($h->{hash_id}, $h->{results}, $test_run_timeout);
        }
    }
}

sub force_end_test {
    my ( $self, $hash_id, $results, $timestamp ) = @_;
    my $result;
    if ( defined $results && $results =~ /^\[/ ) {
        $result = decode_json( $results );
    }
    else {
        $result = [];
    }
    push @$result,
        {
        "level"     => "CRITICAL",
        "module"    => "BACKEND_TEST_AGENT",
        "tag"       => "UNABLE_TO_FINISH_TEST",
        "timestamp" => $timestamp,
        };
    $self->process_unfinished_tests_give_up($result, $hash_id);
}

sub process_dead_test {
    my ( $self, $hash_id, $test_run_max_retries ) = @_;
    my ( $nb_retries, $results ) = $self->dbh->selectrow_array("SELECT nb_retries, results FROM test_results WHERE hash_id = ?", undef, $hash_id);
    if ( $nb_retries < $test_run_max_retries) {
        $self->schedule_for_retry($hash_id);
    } else {
        $self->force_end_test($hash_id, $results, $self->get_relative_start_time($hash_id));
    }
}

=head2 schedule_for_retry

For the test with the given "hash_id" increments its number of retries by 1,
resets its progress to 0 and its start time to NULL.

=cut

sub schedule_for_retry {
    my ( $self, $hash_id ) = @_;

    $self->dbh->do("UPDATE test_results SET nb_retries = nb_retries + 1, progress = 0, test_start_time = NULL WHERE hash_id=?", undef, $hash_id);
}

# A thin wrapper around DBI->connect to ensure similar behavior across database
# engines.
sub _new_dbh {
    my ( $class, $data_source_name, $user, $password ) = @_;

    if ( $user ) {
        $log->noticef( "Connecting to database '%s' as user '%s'", $data_source_name, $user );
    }
    else {
        $log->noticef( "Connecting to database '%s'", $data_source_name );
    }

    my $dbh = DBI->connect(
        $data_source_name,
        $user,
        $password,
        {
            RaiseError => 1,
            AutoCommit => 1,
        }
    );

    $dbh->{AutoInactiveDestroy} = 1;

    return $dbh;
}

sub _project_params {
    my ( $self, $params ) = @_;

    my $profile = Zonemaster::Engine::Profile->effective;

    my %projection = ();

    $projection{domain}   = lc $$params{domain} // "";
    $projection{ipv4}     = $$params{ipv4}      // $profile->get( 'net.ipv4' );
    $projection{ipv6}     = $$params{ipv6}      // $profile->get( 'net.ipv6' );
    $projection{profile}  = $$params{profile}   // "default";

    my $array_ds_info = $$params{ds_info} // [];
    my @array_ds_info_sort = sort {
        $a->{algorithm} cmp $b->{algorithm} or
        $a->{digest}    cmp $b->{digest}    or
        $a->{digtype}   <=> $b->{digtype}   or
        $a->{keytag}    <=> $b->{keytag}
    } @$array_ds_info;

    $projection{ds_info} = \@array_ds_info_sort;

    my $array_nameservers = $$params{nameservers} // [];
    for my $nameserver (@$array_nameservers) {
        if ( defined $$nameserver{ip} and $$nameserver{ip} eq "" ) {
            delete $$nameserver{ip};
        }
        $$nameserver{ns} = lc $$nameserver{ns};
    }
    my @array_nameservers_sort = sort {
        $a->{ns} cmp $b->{ns} or
        ( defined $a->{ip} and defined $b->{ip} and $a->{ip} cmp $b->{ip} )
    } @$array_nameservers;

    $projection{nameservers} = \@array_nameservers_sort;

    return \%projection;
}

sub _params_to_json_str {
    my ( $self, $params ) = @_;

    my $js = JSON::PP->new;
    $js->canonical( 1 );

    my $encoded_params = $js->encode( $params );

    return $encoded_params;
}

=head2 encode_params

Encode the params object into a JSON string. First a projection of some
parameters is performed then all additional properties are kept.
Returns a JSON string of a the using a union of the given hash and its
normalization using default values, see
L<https://github.com/zonemaster/zonemaster-backend/blob/master/docs/API.md#params-2>

=cut

sub encode_params {
    my ( $self, $params ) = @_;

    my $projected_params = $self->_project_params( $params );
    $params = { %$params, %$projected_params };
    my $encoded_params = $self->_params_to_json_str( $params );

    return $encoded_params;
}

=head2 generate_fingerprint

Returns a fingerprint of the hash passed in argument.
The fingerprint is computed after projecting the hash.
Such fingerprint are usefull to find similar tests in the database.

=cut

sub generate_fingerprint {
    my ( $self, $params ) = @_;

    my $projected_params = $self->_project_params( $params );
    my $encoded_params = $self->_params_to_json_str( $projected_params );
    my $fingerprint = md5_hex( encode_utf8( $encoded_params ) );

    return $fingerprint;
}


=head2 undelegated

Returns the value 1 if the test to be created is if type undelegated,
else value 0. The test is considered to be undelegated if the "ds_info" or
"nameservers" parameters is are defined with data after projection.

=cut

sub undelegated {
    my ( $self, $params ) = @_;

    my $projected_params = $self->_project_params( $params );

    return 1 if defined( $$projected_params{ds_info}[0] );
    return 1 if defined( $$projected_params{nameservers}[0] );
    return 0;
}


no Moose::Role;

1;
