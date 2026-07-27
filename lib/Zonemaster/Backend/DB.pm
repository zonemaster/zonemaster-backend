package Zonemaster::Backend::DB;

our $VERSION = '1.2.0';

use Moose::Role;

use 5.14.2;

use Carp        qw( croak );
use DBI         qw( :sql_types );
use Digest::MD5 qw( md5_hex );
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
  is_unknown_table
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

has 'dbhandlepid' => (
    is       => 'rw',
    isa      => 'Maybe[Int]',
    required => 0,
);

=head1 CONSTANTS

=head2 $REQUIRED_SCHEMA_VERSION

A positive integer. The database schema version that this module is compatible with.

=cut

Readonly our $REQUIRED_SCHEMA_VERSION => 2;

=head2 $TEST_WAITING

The test is waiting to be processed.

=cut

Readonly our $TEST_WAITING => 'waiting';

=head2 $TEST_RUNNING

The test is currently being processed.

=cut

Readonly our $TEST_RUNNING => 'running';

=head2 $TEST_COMPLETED

The test was already processed.

=cut

Readonly our $TEST_COMPLETED => 'completed';

=head2 $TEST_CANCELLED

The test was cancelled.

=cut

Readonly our $TEST_CANCELLED => 'cancelled';

=head2 $TEST_CRASHED

The test crashed.

=cut

Readonly our $TEST_CRASHED => 'crashed';


our @EXPORT_OK = qw(
    $TEST_WAITING
    $TEST_RUNNING
    $TEST_COMPLETED
    $TEST_CANCELLED
    $TEST_CRASHED
);


=head1 TEST STATES

Each test in the database is always in exactly one of five formal states. The
state is stored in the C<state> column of the C<test_results> table and is
enforced by a C<CHECK> constraint.

=over 4

=item B<waiting>

The test has been created but is waiting to be picked up for processing.
This is the initial state set by C<create_new_test()>.
In this state C<progress> is C<0> and C<started_at> is C<NULL>.

=item B<running>

The test has been claimed by a worker and is currently being processed.
This state is entered through C<claim_test()>.
In this state C<progress> is in the range 1-99 inclusive and
C<started_at> is set.

=item B<completed>

The test finished normally.
This state is entered through C<set_test_completed()> or C<store_results()>.
In this state C<progress> is C<100> and C<ended_at> is set.

=item B<cancelled>

The test was terminated because it exceeded the configured maximum execution
time.
This state is entered through C<process_unfinished_tests()>.
In this state C<progress> is C<100> and C<ended_at> is set.
The result entries include a C<BACKEND_TEST_AGENT:UNABLE_TO_FINISH_TEST>
message.

=item B<crashed>

The test worker crashed while processing the test.
This state is entered through C<process_dead_test()>.
In this state C<progress> is C<100> and C<ended_at> is set.
The result entries include a C<BACKEND_TEST_AGENT:TEST_DIED> message.

=back

=head2 State transitions

The only legal state transitions are:

  waiting -> running
  running -> completed
  running -> cancelled
  running -> crashed

Any other state change is illegal and causes an error.

=cut


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

    # Do not return the DB handle if it belongs to a different process: we
    # might have forked and be in the child process. If we are not careful, we
    # might be messing with someone else's database connection!
    if ( $self->dbhandle && $self->dbhandle->ping && $self->dbhandlepid && $self->dbhandlepid == $$ ) {
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
    $self->dbhandlepid( $$ );

    return $self->dbhandle;
}

=head2 get_schema_version

Detect the schema version of the database.

Returns an unsigned integer.

The C<0> value means the database is in a schema state prior to schema versioning.

=cut

sub get_schema_version {
    my ( $self ) = @_;

    my $dbh = $self->dbh;

    local $dbh->{RaiseError} = 0;
    local $dbh->{PrintError} = 0;
    my $result = $dbh->selectcol_arrayref( "SELECT version FROM schema_version LIMIT 2" );

    if ( $dbh->err ) {
        if ( !$self->is_unknown_table ) {
            croak "Failed to read schema version: " . $dbh->errstr;
        }

        return 0;
    }

    if (   @$result != 1
        || !defined $result->[0]
        || $result->[0] !~ qr{^[1-9][0-9]*$}
        || $result->[0] < 1 )
    {
        croak 'Invalid schema version declaration';
    }

    return $result->[0];
}

=head2 assert_compatible_schema

Assert that the database has a schema version that is compatible with this version of
Zonemaster Backend.

Croaks if the database has an incompatible schema version, or if it is in an illegal state
with regard to schema version encoding.

=cut

sub assert_compatible_schema {
    my ( $self ) = @_;

    my $db_schema_version = $self->get_schema_version;

    if ( $db_schema_version ne $REQUIRED_SCHEMA_VERSION ) {
        croak "Expected schema version $REQUIRED_SCHEMA_VERSION, found $db_schema_version";
    }

    return;
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
                    state,
                    fingerprint,
                    params,
                    domain,
                    undelegated
                ) VALUES (?,?,?,?,?,?,?,?,?,?)
            ],
            undef,
            $hash_id,
            $batch_id,
            $self->format_time( time() ),
            $priority,
            $queue_label,
            $TEST_WAITING,
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
                  AND state = ?
                  AND progress <= ?
            ],
            undef,
            $progress,
            $test_id,
            $TEST_RUNNING,
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

=head2 test_state( $test_id )

Get the state of the test associated with C<$test_id>.

Returns one of the state constants documented in L</TEST STATES>.

Dies when:

=over 2

=item

attempting to access a test that does not exist

=item

an error occurs in the database interface

=back

=cut

sub test_state {
    my ( $self, $test_id ) = @_;

    my ( $state ) = $self->dbh->selectrow_array(
        q[
            SELECT state
            FROM test_results
            WHERE hash_id = ?
        ],
        undef,
        $test_id,
    );

    if ( !defined $state ) {
        die Zonemaster::Backend::Error::Internal->new( reason => 'job not found' );
    }

    return $state;
}

=head2 set_test_completed( $test_id, [$state] )

Transition a test from the C<running> state to a terminal state.

C<$state> is optional and defaults to C<completed>.
It must be one of the terminal states documented in L</TEST STATES>
(C<completed>, C<cancelled> or C<crashed>).

In the database the test is updated with C<progress> set to 100, the given
C<state> and C<ended_at> set to the current time.

Dies when:

=over 2

=item

attempting to access a test that does not exist

=item

attempting to update a test that is not in the C<running> state

=item

an error occurs in the database interface

=back

=cut

sub set_test_completed {
    my ( $self, $test_id, $state ) = @_;

    $state //= $TEST_COMPLETED;

    my $current_state = $self->test_state( $test_id );

    if ( $current_state ne $TEST_RUNNING ) {
        die Zonemaster::Backend::Error::Internal->new( reason => 'illegal transition to COMPLETED' );
    }

    my $rows_affected = $self->dbh->do(
        q[
            UPDATE test_results
            SET progress = 100,
                state = ?,
                ended_at = ?
            WHERE hash_id = ?
              AND state = ?
        ],
        undef,
        $state,
        $self->format_time( time() ),
        $test_id,
        $TEST_RUNNING,
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
                started_at,
                ended_at,
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
    $result->{started_at} = $self->to_iso8601( $result->{started_at} ) if defined $result->{started_at};
    $result->{ended_at}   = $self->to_iso8601( $result->{ended_at} )   if defined $result->{ended_at};

    return $result;
}

# "$new_results" is JSON encoded
sub store_results {
    my ( $self, $test_id, $new_results ) = @_;

    my $rows_affected = $self->dbh->do(
        q[
            UPDATE test_results
            SET progress = 100,
                state = ?,
                ended_at = ?,
                results = ?
            WHERE hash_id = ?
              AND state = ?
        ],
        undef,
        $TEST_COMPLETED,
        $self->format_time( time() ),
        $new_results,
        $test_id,
        $TEST_RUNNING,
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
        WHERE state IN('completed', 'cancelled', 'crashed') AND domain = ? AND ( ? IS NULL OR undelegated = ? )
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
                    WHERE state = ?
                      AND queue = ?
                    ORDER BY priority DESC,
                             id ASC
                    LIMIT 1
                ],
                undef,
                $TEST_WAITING,
                $queue_label,
            );
        }
        else {
            ( $hash_id, $batch_id ) = $self->dbh->selectrow_array(
                q[
                    SELECT hash_id,
                           batch_id
                    FROM test_results
                    WHERE state = ?
                    ORDER BY priority DESC,
                             id ASC
                    LIMIT 1
                ],
                undef,
                $TEST_WAITING,
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
                state = ?,
                started_at = ?
            WHERE hash_id = ?
              AND state = ?
        ],
        undef,
        $TEST_RUNNING,
        $self->format_time( time() ),
        $test_id,
        $TEST_WAITING,
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
        $self->force_end_test($h->{hash_id}, $msg, $TEST_CANCELLED);
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
            AND state = ?
            AND queue = ?" );
        $sth->execute(    #
            $self->format_time( time() - $test_run_timeout ),
            $TEST_RUNNING,
            $queue_label,
        );
        return $sth;
    }
    else {
        my $sth = $self->dbh->prepare( "
            SELECT hash_id, results
            FROM test_results
            WHERE started_at < ?
            AND state = ?" );
        $sth->execute(    #
            $self->format_time( time() - $test_run_timeout ),
            $TEST_RUNNING,
        );
        return $sth;
    }
}

=head2 force_end_test($hash_id, $msg)

Store the L<Zonemaster::Engine::Logger::Entry> $msg log entry into the database
and mark test with $hash_id as COMPLETED.

=cut

sub force_end_test {
    my ( $self, $hash_id, $msg, $state ) = @_;

    $self->add_result_entries( $hash_id, $msg );
    $self->set_test_completed( $hash_id, $state );
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
    $self->force_end_test($hash_id, $msg, $TEST_CRASHED);
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
