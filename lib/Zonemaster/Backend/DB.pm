package Zonemaster::Backend::DB;

our $VERSION = '1.2.0';

use Moose::Role;

use 5.14.2;

use DBI qw(:sql_types);
use Digest::MD5 qw(md5_hex);
use Encode;
use Exporter qw( import );
use JSON::PP;
use Log::Any qw( $log );
use POSIX qw( strftime );
use Readonly;
use Try::Tiny;

use Zonemaster::Backend::Errors;
use Zonemaster::Engine::Normalization qw( normalize_name trim_space );
use Zonemaster::Engine::Logger::Entry;

requires qw(
  add_batch_job
  create_schema
  drop_tables
  from_config
  get_dbh_specific_attributes
  get_relative_start_time
  is_duplicate
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
    isa      => 'Maybe[DBI::db]',
    required => 1,
);

=head2 $TEST_WAITING

The test is waiting to be processed.

=cut

Readonly our $TEST_WAITING => 'WAITING';

=head2 $TEST_RUNNING

The test is currently being processed.

=cut

Readonly our $TEST_RUNNING => 'RUNNING';

=head2 $TEST_COMPLETED

The test was already processed.

This state encompasses all of the following:

=over 2

=item

The Zonemaster Engine test terminated normally.

=item

A critical error occurred while processing.

=item

The processing was cancelled because it took too long.

=back

=cut

Readonly our $TEST_COMPLETED => 'COMPLETED';

our @EXPORT_OK = qw(
    $TEST_WAITING
    $TEST_RUNNING
    $TEST_COMPLETED
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

    if ( $self->dbhandle && $self->dbhandle->ping ) {
        return $self->dbhandle;
    }

    if ( $self->user ) {
        $log->noticef( "Connecting to database '%s' as user '%s'", $self->data_source_name, $self->user );
    }
    else {
        $log->noticef( "Connecting to database '%s'", $self->data_source_name );
    }

    my $attr = {
        RaiseError          => 1,
        AutoCommit          => 1,
        AutoInactiveDestroy => 1,
    };

    $attr = { %$attr, %{ $self->get_dbh_specific_attributes } };

    my $dbh = DBI->connect(
        $self->data_source_name,
        $self->user,
        $self->password,
        $attr
    );

    $self->dbhandle( $dbh );

    return $self->dbhandle;
}

sub add_api_user {
    my ( $self, $username, $api_key ) = @_;

    die Zonemaster::Backend::Error::Internal->new( reason => "username or api_key not provided to the method add_api_user")
        unless ( $username && $api_key );

    my $dbh = $self->dbh;
    my $result;

    try {
        $result = $dbh->do(
            "INSERT INTO users (username, api_key) VALUES (?,?)",
            undef,
            $username,
            $api_key,
        );
    } catch {
        die Zonemaster::Backend::Error::Conflict->new( message => 'User already exists', data => { username => $username } )
            if ( $self->is_duplicate );
    };

    die Zonemaster::Backend::Error::Internal->new( reason => "add_api_user not successful")
        unless ( $result );

    return $result;
}

sub create_new_test {
    my ( $self, $domain, $test_params, $seconds_between_tests_with_same_params, $batch_id ) = @_;

    my $dbh = $self->dbh;

    $test_params->{domain} = _normalize_domain( $domain );

    my $fingerprint = $self->generate_fingerprint( $test_params );
    my $encoded_params = $self->encode_params( $test_params );
    my $undelegated = $self->undelegated ( $test_params );

    my $hash_id;

    my $priority    = $test_params->{priority};
    my $queue_label = $test_params->{queue};
    my $now         = time();
    my $threshold   = $now - $seconds_between_tests_with_same_params;

    my $recent_hash_id = $self->recent_test_hash_id( $fingerprint, $threshold );

    if ( $recent_hash_id ) {
        # A recent entry exists, so return its id
        $hash_id = $recent_hash_id;
    }
    else {
        $hash_id = substr(md5_hex($now.rand()), 0, 16);
        $dbh->do(
            q[
                INSERT INTO test_results (
                    hash_id,
                    batch_id,
                    created_at,
                    priority,
                    queue,
                    fingerprint,
                    params,
                    domain,
                    undelegated
                ) VALUES (?,?,?,?,?,?,?,?,?)
            ],
            undef,
            $hash_id,
            $batch_id,
            $self->format_time( time() ),
            $priority,
            $queue_label,
            $fingerprint,
            $encoded_params,
            encode_utf8( $test_params->{domain} ),
            $undelegated,
        );
    }

    return $hash_id;
}

# Search for recent test result with the test same parameters, where
# "threshold" gives the oldest start time.
sub recent_test_hash_id {
    my ( $self, $fingerprint, $threshold ) = @_;

    my $dbh = $self->dbh;
    my ( $recent_hash_id ) = $dbh->selectrow_array(
        q[
            SELECT hash_id
            FROM test_results
            WHERE fingerprint = ?
              AND batch_id IS NULL
              AND ( started_at IS NULL
                 OR started_at >= ? )
        ],
        undef,
        $fingerprint,
        $self->format_time( $threshold ),
    );

    return $recent_hash_id;
}

=head2 test_progress( $test_id, $progress )

Get/set the progress value of the test associated with C<$test_id>.

The given C<$progress> must be either C<undef> (when getting) or an number in
the range 0-100 inclusive (when setting).

If defined, C<$progress> is clamped to 1-99 inclusive.

Dies when:

=over 2

=item

attempting to access a test that does not exist

=item

attempting to update a test that is in a state other than "running"

=item

attempting to set a progress value that is lower than the current one

=item

an error occurs in the database interface

=back

=cut

sub test_progress {
    my ( $self, $test_id, $progress ) = @_;

    if ( defined $progress ) {
        if ( $progress < 0 || 100 < $progress ) {
            die Zonemaster::Backend::Error::Internal->new( reason => "progress out of range" );
        } elsif ( $progress < 1 ) {
            $progress = 1;
        } elsif ( 99 < $progress ) {
            $progress = 99;
        }

        my $rows_affected = $self->dbh->do(
            q[
                UPDATE test_results
                SET progress = ?
                WHERE hash_id = ?
                  AND 1 <= progress
                  AND progress <= ?
            ],
            undef,
            $progress,
            $test_id,
            $progress,
        );
        if ( $rows_affected == 0 ) {
            die Zonemaster::Backend::Error::Internal->new( reason => 'job not found or illegal update' );
        }

        return $progress;
    }

    my ( $result ) = $self->dbh->selectrow_array(
        q[
            SELECT progress
            FROM test_results
            WHERE hash_id = ?
        ],
        undef,
        $test_id,
    );
    if ( !defined $result ) {
        die Zonemaster::Backend::Error::Internal->new( reason => 'job not found' );
    }

    return $result;
}

sub test_state {
    my ( $self, $test_id ) = @_;

    my ( $progress ) = $self->dbh->selectrow_array(
        q[
            SELECT progress
            FROM test_results
            WHERE hash_id = ?
        ],
        undef,
        $test_id,
    );
    if ( !defined $progress ) {
        die Zonemaster::Backend::Error::Internal->new( reason => 'job not found' );
    }

    if ( $progress == 0 ) {
        return $TEST_WAITING;
    }
    elsif ( 0 < $progress && $progress < 100 ) {
        return $TEST_RUNNING;
    }
    elsif ( $progress == 100 ) {
        return $TEST_COMPLETED;
    }
    else {
        die Zonemaster::Backend::Error::Internal->new( reason => 'state could not be determined' );
    }
}

sub set_test_completed {
    my ( $self, $test_id ) = @_;

    my $current_state = $self->test_state( $test_id );

    if ( $current_state ne $TEST_RUNNING ) {
        die Zonemaster::Backend::Error::Internal->new( reason => 'illegal transition to COMPLETED' );
    }

    my $rows_affected = $self->dbh->do(
        q[
            UPDATE test_results
            SET progress = 100,
                ended_at = ?
            WHERE hash_id = ?
              AND 0 < progress
              AND progress < 100
        ],
        undef,
        $self->format_time( time() ),
        $test_id,
    );

    if ( $rows_affected == 0 ) {
        die Zonemaster::Backend::Error::Internal->new( reason => "job not found or illegal transition" );
    }
}

sub select_test_results {
    my ( $self, $test_id ) = @_;

    my ( $hrefs ) = $self->dbh->selectall_hashref(
        q[
            SELECT
                hash_id,
                created_at,
                params
            FROM test_results
            WHERE hash_id = ?
        ],
        'hash_id',
        undef,
        $test_id
    );

    my $result = $hrefs->{$test_id};

    die Zonemaster::Backend::Error::ResourceNotFound->new( message => "Test not found", data => { test_id => $test_id } )
        unless defined $result;

    $result->{created_at} = $self->to_iso8601( $result->{created_at} );

    return $result;
}

# "$new_results" is JSON encoded
sub store_results {
    my ( $self, $test_id, $new_results ) = @_;

    my $rows_affected = $self->dbh->do(
        q[
            UPDATE test_results
            SET progress = 100,
                ended_at = ?,
                results = ?
            WHERE hash_id = ?
              AND 0 < progress
              AND progress < 100
        ],
        undef,
        $self->format_time( time() ),
        $new_results,
        $test_id,
    );

    if ( $rows_affected == 0 ) {
        die Zonemaster::Backend::Error::Internal->new( reason => "job not found or illegal transition" );
    }

    return;
}

sub test_results {
    my ( $self, $test_id ) = @_;

    my $result = $self->select_test_results( $test_id );

    my @result_entries = $self->dbh->selectall_array(
        q[
            SELECT
                l.level,
                r.module,
                r.testcase,
                r.tag,
                r.timestamp,
                r.args
            FROM result_entries r
            INNER JOIN log_level l
                ON r.level = l.value
            WHERE hash_id = ?
        ],
        { Slice => {} },
        $test_id
    );

    eval {
        $result->{params}  = decode_json( $result->{params} );

        @result_entries = map {
            {
                %$_,
                args => decode_json( $_->{args} ),
            }
        } @result_entries;

        $result->{results} = \@result_entries;
    };

    die Zonemaster::Backend::Error::JsonError->new( reason => "$@", data => { test_id => $test_id } )
        if $@;

    return $result;
}

sub get_test_history {
    my ( $self, $p ) = @_;

    my $dbh = $self->dbh;

    my $undelegated = undef;
    if ($p->{filter} eq "undelegated") {
        $undelegated = 1;
    } elsif ($p->{filter} eq "delegated") {
        $undelegated = 0;
    }

    my @results;
    my $query = q[
        SELECT
            (SELECT count(*) FROM result_entries WHERE result_entries.hash_id = test_results.hash_id AND level = ?) AS nb_critical,
            (SELECT count(*) FROM result_entries WHERE result_entries.hash_id = test_results.hash_id AND level = ?) AS nb_error,
            (SELECT count(*) FROM result_entries WHERE result_entries.hash_id = test_results.hash_id AND level = ?) AS nb_warning,
            id,
            hash_id,
            created_at,
            undelegated
        FROM test_results
        WHERE progress = 100 AND domain = ? AND ( ? IS NULL OR undelegated = ? )
        ORDER BY created_at DESC
        LIMIT ?
        OFFSET ?];

    my $sth = $dbh->prepare( $query );

    my %levels = Zonemaster::Engine::Logger::Entry->levels();
    $sth->bind_param( 1, $levels{CRITICAL} );
    $sth->bind_param( 2, $levels{ERROR} );
    $sth->bind_param( 3, $levels{WARNING} );
    $sth->bind_param( 4, _normalize_domain( $p->{frontend_params}{domain} ) );
    $sth->bind_param( 5, $undelegated, SQL_INTEGER );
    $sth->bind_param( 6, $undelegated, SQL_INTEGER );
    $sth->bind_param( 7, $p->{limit} );
    $sth->bind_param( 8, $p->{offset} );

    $sth->execute();

    while ( my $h = $sth->fetchrow_hashref ) {
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
                id               => $h->{hash_id},
                created_at       => $self->to_iso8601( $h->{created_at} ),
                undelegated      => $h->{undelegated},
                overall_result   => $overall_result,
            }
        );
    }

    return \@results;
}

sub create_new_batch_job {
    my ( $self, $username ) = @_;

    my $dbh = $self->dbh;
    $dbh->do( q[ INSERT INTO batch_jobs (username, created_at) VALUES (?,?) ],
        undef,
        $username,
        $self->format_time( time() ),
    );
    my $new_batch_id = $dbh->last_insert_id( undef, undef, "batch_jobs", undef );

    return $new_batch_id;
}

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

sub batch_exists_in_db {
    my ( $self, $batch_id ) = @_;

    my $dbh = $self->dbh;
    my ( $id ) = $dbh->selectrow_array(
        q[ SELECT id FROM batch_jobs WHERE id = ? ],
        undef,
        $batch_id
    );

    return $id;
}

=head2 get_test_request( $queue_label )

Find a waiting test and claim it for processing.

If $queue_label is defined it must be an integer.
If defined, only tests in the associated queue are considered.
Otherwise tests from all queues are considered.

Returns the test id and the batch id of the claimed test.
If there are no waiting tests to claim, C<undef> is returned for both ids.

Only tests in the "waiting" state are considered.
When a test is claimed it is removed from the queue and it transitions to the
"running" state.

It is safe for multiple callers running in parallel to allocate tests from the
same queues.

Dies when an error occurs in the database interface.

=cut

sub get_test_request {
    my ( $self, $queue_label ) = @_;

    while ( 1 ) {

        # Identify a candidate for allocation ...
        my ( $hash_id, $batch_id );
        if ( defined $queue_label ) {
            ( $hash_id, $batch_id ) = $self->dbh->selectrow_array(
                q[
                    SELECT hash_id,
                           batch_id
                    FROM test_results
                    WHERE progress = 0
                      AND queue = ?
                    ORDER BY priority DESC,
                             id ASC
                    LIMIT 1
                ],
                undef,
                $queue_label,
            );
        }
        else {
            ( $hash_id, $batch_id ) = $self->dbh->selectrow_array(
                q[
                    SELECT hash_id,
                           batch_id
                    FROM test_results
                    WHERE progress = 0
                    ORDER BY priority DESC,
                             id ASC
                    LIMIT 1
                ],
            );
        }

        if ( defined $hash_id ) {

            # ... and race to be the first to claim it ...
            if ( $self->claim_test( $hash_id ) ) {
                return ( $hash_id, $batch_id );
            }
        }
        else {
            # ... or stop trying if there are no candidates.
            return ( undef, undef );
        }
    }
}

=head2 claim_test( $test_id )

Claim a test for processing.

Transitions a test from the "waiting" state to the "running" state.

Returns true on successful transition.
Returns false if the given test does not exist or if it is not in the "waiting"
state.

Dies when an error occurs in the database interface.

=cut

sub claim_test {
    my ( $self, $test_id ) = @_;

    my $rows_affected = $self->dbh->do(
        q[
            UPDATE test_results
            SET progress = 1,
                started_at = ?
            WHERE hash_id = ?
              AND progress = 0
        ],
        undef,
        $self->format_time( time() ),
        $test_id,
    );

    return $rows_affected == 1;
}

sub get_test_params {
    my ( $self, $test_id ) = @_;

    my $dbh = $self->dbh;
    my ( $params_json ) = $dbh->selectrow_array( "SELECT params FROM test_results WHERE hash_id = ?", undef, $test_id );

    die Zonemaster::Backend::Error::ResourceNotFound->new( message => "Test not found", data => { test_id => $test_id } )
        unless defined $params_json;

    my $result;
    eval {
        $result = decode_json( $params_json );
    };

    die Zonemaster::Backend::Error::JsonError->new( reason => "$@", data => { test_id => $test_id } )
        if $@;

    return $result;
}

# Standatd SQL, can be here
sub get_batch_job_result {
    my ( $self, $batch_id ) = @_;

    die Zonemaster::Backend::Error::ResourceNotFound->new( message => "Unknown batch", data => { batch_id => $batch_id } )
        unless defined $self->batch_exists_in_db( $batch_id );

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

=head2 batch_status

Returns number of tests per category (finished, running, waiting) for the given
batch, provided as C<batch_id>.

If one or more of parameters C<list_running_tests>, C<list_finished_tests> or
C<list_waiting_tests> are included with true value, the C<hash_id> values for
that category is also included.

=cut

# Standard SQL, can be here
sub batch_status {
    my ( $self, $test_params ) = @_;

    my $batch_id = $test_params->{batch_id};

    die Zonemaster::Backend::Error::ResourceNotFound->new( message => "Unknown batch", data => { batch_id => $batch_id } )
        unless defined $self->batch_exists_in_db( $batch_id );

    my $dbh = $self->dbh;

    my %result;
    $result{waiting_count} = 0;
    $result{running_count} = 0;
    $result{finished_count} = 0;

    my $query = "
        SELECT hash_id, progress
        FROM test_results
        WHERE batch_id=?";

    my $sth1 = $dbh->prepare( $query );
    $sth1->execute( $batch_id );

    while ( my $h = $sth1->fetchrow_hashref ) {
        if ( $h->{progress} eq '0' ) {
            $result{waiting_count}++;
            push(@{$result{waiting_tests}}, $h->{hash_id}) if $test_params->{list_waiting_tests};
        }
        elsif ( $h->{progress} eq '100' ) {
            $result{finished_count}++;
            push(@{$result{finished_tests}}, $h->{hash_id}) if $test_params->{list_finished_tests};
        }
        else {
            $result{running_count}++;
            push(@{$result{running_tests}}, $h->{hash_id}) if $test_params->{list_running_tests};
        }
    }

    return \%result;
}


=head2 process_unfinished_tests($queue_label, $test_run_timeout)

Append a new log entry C<BACKEND_TEST_AGENT:UNABLE_TO_FINISH_TEST> to all the
tests started more that $test_run_timeout seconds in the queue $queue_label.
Then store the results in database.

=cut

sub process_unfinished_tests {
    my ( $self, $queue_label, $test_run_timeout ) = @_;

    my $sth1 = $self->select_unfinished_tests(    #
        $queue_label,
        $test_run_timeout,
    );

    my $msg = Zonemaster::Engine::Logger::Entry->new(
        {
            level     => "CRITICAL",
            module    => "Backend",
            testcase  => "",
            tag       => "UNABLE_TO_FINISH_TEST",
            args      => { max_execution_time => $test_run_timeout },
            timestamp => $test_run_timeout
        }
    );
    while ( my $h = $sth1->fetchrow_hashref ) {
        $self->force_end_test($h->{hash_id}, $msg);
    }
}

=head2 select_unfinished_tests($queue_label, $test_run_timeout)

Search for all tests started more than $test_run_timeout seconds in the queue
$queue_label.

=cut

sub select_unfinished_tests {
    my ( $self, $queue_label, $test_run_timeout ) = @_;

    if ( $queue_label ) {
        my $sth = $self->dbh->prepare( "
            SELECT hash_id, results
            FROM test_results
            WHERE started_at < ?
            AND progress > 0
            AND progress < 100
            AND queue = ?" );
        $sth->execute(    #
            $self->format_time( time() - $test_run_timeout ),
            $queue_label,
        );
        return $sth;
    }
    else {
        my $sth = $self->dbh->prepare( "
            SELECT hash_id, results
            FROM test_results
            WHERE started_at < ?
            AND progress > 0
            AND progress < 100" );
        $sth->execute(    #
            $self->format_time( time() - $test_run_timeout ),
        );
        return $sth;
    }
}

=head2 force_end_test($hash_id, $msg)

Store the L<Zonemaster::Engine::Logger::Entry> $msg log entry into the database
and mark test with $hash_id as COMPLETED.

=cut

sub force_end_test {
    my ( $self, $hash_id, $msg ) = @_;

    $self->add_result_entries( $hash_id, $msg );
    $self->set_test_completed( $hash_id );
}

=head2 process_dead_test($hash_id)

Store a new log entry C<BACKEND_TEST_AGENT:TEST_DIED> in database for the test
with $hash_id.

=cut

sub process_dead_test {
    my ( $self, $hash_id ) = @_;
    my $msg = Zonemaster::Engine::Logger::Entry->new(
        {
            level     => "CRITICAL",
            module    => "Backend",
            testcase  => "",
            tag       => "TEST_DIED",
            args      => {},
            timestamp => $self->get_relative_start_time($hash_id)
        }
    );
    $self->force_end_test($hash_id, $msg);
}

# Converts the domain to lowercase and if the domain is not the root ('.')
# removes any trailing dot
sub _normalize_domain {
    my ( $domain ) = @_;

    my ( $errors, $normalized_domain ) = normalize_name( trim_space( $domain ) );

    if ( scalar( @{$errors} ) ) {
        die Zonemaster::Backend::Error::Internal->new( reason => "Normalizing domain returned errors.", data => [ map { $_->string } @{$errors} ] );
    }

    return $normalized_domain;
}

sub _project_params {
    my ( $self, $params ) = @_;

    my %projection = ();

    $projection{domain}   = _normalize_domain( $$params{domain} // "" );
    $projection{ipv4}     = $$params{ipv4};
    $projection{ipv6}     = $$params{ipv6};
    $projection{profile}  = lc( $$params{profile} // "default" );

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
        $$nameserver{ns} = _normalize_domain( $$nameserver{ns} );
    }
    my @array_nameservers_sort = sort {
        $a->{ns} cmp $b->{ns} or
        ( defined $a->{ip} and defined $b->{ip} and $a->{ip} cmp $b->{ip} )
    } @$array_nameservers;

    $projection{nameservers} = \@array_nameservers_sort;

    return \%projection;
}

# Take a params object with text strings and return an UTF-8 binary string
sub _params_to_json_str {
    my ( $self, $params ) = @_;

    my $js = JSON::PP->new;
    $js->canonical( 1 );
    $js->utf8( 1 );

    my $encoded_params = $js->encode( $params );

    return $encoded_params;
}

=head2 encode_params

Encode the params object into a JSON string. First a projection of some
parameters is performed then all additional properties are kept.
Returns an UTF-8  binary string of the union of the given hash and its
normalization using default values, see
L<https://github.com/zonemaster/zonemaster/blob/master/docs/public/using/backend/rpcapi-reference.md#params-2>

=cut

sub encode_params {
    my ( $self, $params ) = @_;

    my $projected_params = $self->_project_params( $params );
    $params = { %$params, %$projected_params };
    my $encoded_params = $self->_params_to_json_str( $params );

    return $encoded_params;
}

=head2 generate_fingerprint

Returns a fingerprint (an UTF-8 binary string) of the hash passed in argument
(which contain text string).
The fingerprint is computed after projecting the hash.
Such fingerprint are usefull to find similar tests in the database.

=cut

sub generate_fingerprint {
    my ( $self, $params ) = @_;

    my $projected_params = $self->_project_params( $params );
    my $encoded_params = $self->_params_to_json_str( $projected_params );
    my $fingerprint = md5_hex( $encoded_params );

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

sub format_time {
    my ( $class, $time ) = @_;
    return strftime "%Y-%m-%d %H:%M:%S", gmtime( $time );
}

sub to_iso8601 {
    my ( $class, $time ) = @_;
    $time =~ s/^([^ ]+) (.*)$/$1T$2Z/;
    return $time;
}

sub add_result_entries {
    my ( $self, $hash_id, @entries ) = @_;
    my @records;

    my $json = JSON::PP->new->allow_blessed->convert_blessed->canonical;

    my %levels = Zonemaster::Engine::Logger::Entry->levels();

    foreach my $e ( @entries ) {
        my $r = [
            $hash_id,
            $levels{ $e->level },
            $e->module,
            $e->testcase,
            $e->tag,
            $e->timestamp,
            $json->encode( $e->args // {} ),
        ];

        push @records, $r;
    }
    my $query_values = join ", ", ("(?, ?, ?, ?, ?, ?, ?)") x @records;
    my $query = "INSERT INTO result_entries (hash_id, level, module, testcase, tag, timestamp, args) VALUES $query_values";
    my $sth = $self->dbh->prepare($query);
    $sth = $sth->execute(map { @$_ } @records);
}

no Moose::Role;

1;
