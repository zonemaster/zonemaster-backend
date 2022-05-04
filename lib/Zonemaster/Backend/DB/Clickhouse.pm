package Zonemaster::Backend::DB::Clickhouse;

our $VERSION = '1.0.0';

use Moose;
use 5.14.2;

use DBI qw(:utils :sql_types);
use Digest::MD5 qw(md5_hex);
use JSON::PP;
use Log::Any qw( $log );

use Zonemaster::Backend::Validator qw( untaint_ipv6_address );
use Zonemaster::Backend::Errors;
use Zonemaster::Backend::DB qw( $TEST_WAITING $TEST_RUNNING );

with 'Zonemaster::Backend::DB';

=head1 Prepare Clickhouse

=over

=item Create a database.

  CREATE DATABASE zonemaster;

=item Create a user to access the database and grant access

  CREATE USER zonemaster IDENTIFIED WITH double_sha1_hash BY 'c48af24281c01c4bb37b78218f8098e99f60a2ec';
  GRANT CREATE TABLE, DROP TABLE, SELECT, INSERT, ALTER UPDATE ON zonemaster.* TO zonemaster;

=back


=head1 CLASS METHODS

=head2 from_config

Construct a new instance from a Zonemaster::Backend::Config.

    my $db = Zonemaster::Backend::DB::Clickhouse->from_config( $config );

=cut

sub from_config {
    my ( $class, $config ) = @_;

    my $database = $config->CLICKHOUSE_database;
    my $host     = $config->CLICKHOUSE_host;
    my $port     = $config->CLICKHOUSE_port;
    my $user     = $config->CLICKHOUSE_user;
    my $password = $config->CLICKHOUSE_password;

    if ( untaint_ipv6_address( $host ) ) {
        $host = "[$host]";
    }

    my $data_source_name = "DBI:mysql:database=$database;host=$host;port=$port";

    return $class->new(
        {
            data_source_name => $data_source_name,
            user             => $user,
            password         => $password,
            dbhandle         => undef,
        }
    );
}

sub get_dbh_specific_attributes {
    return {};
}

# Use non-replicated table so that ALTER queries are synchronous
# https://clickhouse.com/docs/en/sql-reference/statements/alter#synchronicity-of-alter-queries
sub create_schema {
    my ( $self ) = @_;

    my $dbh = $self->dbh;

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $dbh->do( q[
        CREATE TABLE IF NOT EXISTS test_results (
            hash_id FixedString(16),
            domain String,
            batch_id UInt32,
            created_at DateTime('UTC'),
            started_at Nullable(DateTime('UTC')),
            ended_at Nullable(DateTime('UTC')),
            priority UInt32 DEFAULT 10,
            queue UInt32 DEFAULT 0,
            progress UInt8 DEFAULT 0,
            fingerprint FixedString(32),
            params String,
            results Nullable(String),
            undelegated UInt8
        ) ENGINE = MergeTree()
        PARTITION BY toYYYYMM(created_at)
        ORDER BY (created_at, hash_id, domain, priority)
        ]
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "Clickhouse error, could not create 'test_results' table", data => $dbh->errstr() );

    ####################################################################
    # LOG LEVEL
    ####################################################################
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS log_level (
            value Int8,
            level String
        ) ENGINE = MergeTree()
        ORDER BY value
        "
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "Clickhouse error, could not create 'log_level' table", data => $dbh->errstr() );

    my ( $c ) = $dbh->selectrow_array( "SELECT count(*) FROM log_level" );
    if ( $c == 0 ) {
        $dbh->do(
            "INSERT INTO log_level (value, level)
            VALUES
                (-2, 'DEBUG3'),
                (-1, 'DEBUG2'),
                ( 0, 'DEBUG'),
                ( 1, 'INFO'),
                ( 2, 'NOTICE'),
                ( 3, 'WARNING'),
                ( 4, 'ERROR'),
                ( 5, 'CRITICAL')
            "
        );
    }

    ####################################################################
    # RESULT ENTRIES
    ####################################################################
    $dbh->do( q[
        CREATE TABLE IF NOT EXISTS result_entries (
            date DateTime('UTC') DEFAULT now(),
            hash_id FixedString(16),
            level Int8,
            module varchar(255),
            testcase String,
            tag String,
            timestamp Float32,
            args String
        ) ENGINE = MergeTree()
        PARTITION BY toYYYYMM(date)
        ORDER BY (date, hash_id, module, testcase, tag, level)
        ]
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "Clickhouse error, could not create 'result_entries' table", data => $dbh->errstr() );


    ####################################################################
    # BATCH JOBS
    ####################################################################
    # TODO: manually populate id field for batch_jobs
    $dbh->do( q[
        CREATE TABLE IF NOT EXISTS batch_jobs (
            id UInt32,
            username String,
            created_at DateTime('UTC')
        ) ENGINE = MergeTree()
        ORDER BY (id, username, created_at)
        ]
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "Clickhouse error, could not create 'batch_jobs' table", data => $dbh->errstr() );


    ####################################################################
    # USERS
    ####################################################################
    $dbh->do( q[
        CREATE TABLE IF NOT EXISTS users (
            username String,
            api_key String
        ) ENGINE = MergeTree()
        ORDER BY (username)
        ]
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "Clickhouse error, could not create 'users' table", data => $dbh->errstr() );

    return;
}

=head2 drop_tables

Drop all the tables if they exist.

=cut

sub drop_tables {
    my ( $self ) = @_;

    $self->dbh->do( "DROP TABLE IF EXISTS test_results" );
    $self->dbh->do( "DROP TABLE IF EXISTS result_entries" );
    $self->dbh->do( "DROP TABLE IF EXISTS log_level" );
    $self->dbh->do( "DROP TABLE IF EXISTS users" );
    $self->dbh->do( "DROP TABLE IF EXISTS batch_jobs" );

    return;
}

sub _user_exists {
    my ( $self, $username ) = @_;

    my $dbh = $self->dbh;

    my ( $count ) = $dbh->selectrow_array(
        "SELECT count(*) FROM users WHERE username = ?",
        undef,
        $username
    );

    return $count;
}

sub add_api_user {
    my ( $self, $username, $api_key ) = @_;

    die Zonemaster::Backend::Error::Internal->new( reason => "username or api_key not provided to the method add_api_user")
        unless ( $username && $api_key );

    my $dbh = $self->dbh;
    my $result;

    # FIXME a race condition could occur
    if ( 1 == $self->_user_exists( $username ) ) {
        die Zonemaster::Backend::Error::Conflict->new( message => 'User already exists', data => { username => $username } )
    }

    eval {
        $result = $dbh->do(
            "INSERT INTO users (username, api_key) VALUES (?,?)",
            undef,
            $username,
            $api_key,
        );
    };

    die Zonemaster::Backend::Error::Internal->new( reason => "add_api_user not successful")
        unless ( $result );

    return $result;
}

sub add_batch_job {
    my ( $self, $params ) = @_;
    my $batch_id;

    my $dbh = $self->dbh;

    if ( 1 == $self->user_authorized( $params->{username}, $params->{api_key} ) ) {
        $batch_id = $self->create_new_batch_job( $params->{username} );

        my $test_params = $params->{test_params};
        my $priority    = $test_params->{priority};
        my $queue_label = $test_params->{queue};

        my @values;

        foreach my $domain ( @{$params->{domains}} ) {
            $test_params->{domain} = _normalize_domain( $domain );

            my $fingerprint = $self->generate_fingerprint( $test_params );
            my $encoded_params = $self->encode_params( $test_params );
            my $undelegated = $self->undelegated ( $test_params );

            my $hash_id = substr(md5_hex(time().rand()), 0, 16);

            my $v = [
                $hash_id,
                $test_params->{domain},
                $batch_id,
                $self->format_time( time() ),
                $priority,
                $queue_label,
                $fingerprint,
                $encoded_params,
                $undelegated,
            ];

            push @values, $v;
        }

        my $query_values = join ", ", ("(?,?,?,?,?,?,?,?,?)") x @values;
        my $sth = $dbh->prepare(
            "
                INSERT INTO test_results (
                    hash_id,
                    domain,
                    batch_id,
                    created_at,
                    priority,
                    queue,
                    fingerprint,
                    params,
                    undelegated
                ) VALUES $query_values
            "
        );
        $sth->execute(map { @$_ } @values);
    }
    else {
        die Zonemaster::Backend::Error::PermissionDenied->new( message => 'User not authorized to use batch mode', data => { username => $params->{username}} );
    }

    return $batch_id;
}

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
                ALTER TABLE test_results
                UPDATE progress = ?
                WHERE hash_id = ?
                  AND 1 <= progress
                  AND progress <= ?
                SETTINGS mutations_sync = 1
            ],
            undef,
            $progress,
            $test_id,
            $progress,
        );

        # number of affected rows is incorrect in Clickhouse and this is a feature
        # see <https://github.com/ClickHouse/ClickHouse/issues/50970#issuecomment-1591333551>
        ( $rows_affected ) = $self->dbh->selectrow_array(
            q[
              SELECT count(*)
              FROM test_results
              WHERE hash_id = ?
                AND progress = ?
            ],
            undef,
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

sub set_test_completed {
    my ( $self, $test_id ) = @_;

    my $current_state = $self->test_state( $test_id );

    if ( $current_state ne $TEST_RUNNING ) {
        die Zonemaster::Backend::Error::Internal->new( reason => 'illegal transition to COMPLETED' );
    }

    my $rows_affected = $self->dbh->do(
        q[
            ALTER TABLE test_results
            UPDATE progress = 100,
                ended_at = ?
            WHERE hash_id = ?
              AND 0 < progress
              AND progress < 100
            SETTINGS mutations_sync = 1
        ],
        undef,
        $self->format_time( time() ),
        $test_id,
    );

    # number of affected rows is incorrect in Clickhouse and this is a feature
    # see <https://github.com/ClickHouse/ClickHouse/issues/50970#issuecomment-1591333551>
    ( $rows_affected ) = $self->dbh->selectrow_array(
        q[
          SELECT count(*)
          FROM test_results
          WHERE hash_id = ?
            AND progress = 100
        ],
        undef,
        $test_id,
    );

    if ( $rows_affected == 0 ) {
        die Zonemaster::Backend::Error::Internal->new( reason => "job not found or illegal transition" );
    }
}

# "$new_results" is JSON encoded
sub store_results {
    my ( $self, $test_id, $new_results ) = @_;

    if ( $self->test_state( $test_id ) ne $TEST_RUNNING ) {
        die Zonemaster::Backend::Error::Internal->new( reason => "illegal transition" );
    }

    my $rows_affected = $self->dbh->do(
        q[
            ALTER TABLE test_results
            UPDATE progress = 100,
                ended_at = ?,
                results = ?
            WHERE hash_id = ?
              AND 0 < progress
              AND progress < 100
            SETTINGS mutations_sync = 1
        ],
        undef,
        $self->format_time( time() ),
        $new_results,
        $test_id,
    );

    # number of affected rows is incorrect in Clickhouse and this is a feature
    # see <https://github.com/ClickHouse/ClickHouse/issues/50970#issuecomment-1591333551>
    ( $rows_affected ) = $self->dbh->selectrow_array(
        q[
          SELECT count(*)
          FROM test_results
          WHERE hash_id = ?
            AND progress = 100
        ],
        undef,
        $test_id
    );

    if ( $rows_affected == 0 ) {
        die Zonemaster::Backend::Error::Internal->new( reason => "job not found or illegal transition" );
    }

    return;
}

# Almost the same as the one in DB.pm. The only difference is that
# it relies on "created_at" instead of the "id" field which is not
# defined in Clickhouse
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
                             created_at ASC
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
                             created_at ASC
                    LIMIT 1
                ],
            );
        }

        if ( defined $hash_id ) {

            # ... and race to be the first to claim it ...
            if ( $self->claim_test( $hash_id ) ) {
                # in Clickhouse batch_id is a non-NULL UInt32 and starts at 1
                $batch_id = $batch_id > 0 ? $batch_id : undef;
                return ( $hash_id, $batch_id );
            }
        }
        else {
            # ... or stop trying if there are no candidates.
            return ( undef, undef );
        }
    }
}

# specific ALTER UPDATE syntax for Clickhouse
sub claim_test {
    my ( $self, $test_id ) = @_;

    if ( $self->test_state( $test_id ) ne $TEST_WAITING ) {
        return '';
    }

    my $rows_affected = $self->dbh->do(
        q[
            ALTER TABLE test_results
            UPDATE progress = 1,
                started_at = ?
            WHERE hash_id = ?
              AND progress = 0
            SETTINGS mutations_sync = 1
        ],
        undef,
        $self->format_time( time() ),
        $test_id,
    );

    # number of affected rows is incorrect in Clickhouse and this is a feature
    # see <https://github.com/ClickHouse/ClickHouse/issues/50970#issuecomment-1591333551>
    ( $rows_affected ) = $self->dbh->selectrow_array(
        q[
          SELECT count(*)
          FROM test_results
          WHERE hash_id = ?
            AND progress = 1
        ],
        undef,
        $test_id
    );

    return $rows_affected == 1;
}

sub create_new_batch_job {
    my ( $self, $username ) = @_;

    my $dbh = $self->dbh;
    $dbh->do(
        q[
            INSERT INTO batch_jobs (id, username, created_at)
            SELECT max(id) + 1, toString(?), ? FROM batch_jobs ],
        undef,
        $username,
        $self->format_time( time() ),
    );
    my ( $new_batch_id ) = $dbh->selectrow_array( q[ SELECT max(id) FROM batch_jobs ] );

    return $new_batch_id;
}

sub get_relative_start_time {
    my ( $self, $hash_id ) = @_;

    return $self->dbh->selectrow_array(
        q[
            SELECT date_diff( 'second', started_at, toDateTime( ?, 'UTC' ) )
            FROM test_results
            WHERE hash_id = ?
        ],
        undef,
        $self->format_time( time() ),
        $hash_id,
    );
}

sub recent_test_hash_id {
    my ( $self, $fingerprint, $threshold ) = @_;

    my $dbh = $self->dbh;
    my ( $recent_hash_id ) = $dbh->selectrow_array(
        q[
            SELECT hash_id
            FROM test_results
            WHERE fingerprint = ?
              AND batch_id = 0
              AND ( started_at IS NULL
                 OR started_at >= toDateTime( ?, 'UTC' ) )
        ],
        undef,
        $fingerprint,
        $self->format_time( $threshold ),
    );

    return $recent_hash_id;
}


sub is_duplicate {
    my ( $self ) = @_;

    # for the list of codes see:
    # https://mariadb.com/kb/en/mariadb-error-codes/
    # https://dev.mysql.com/doc/mysql-errors/8.0/en/server-error-reference.html
    return ( $self->dbh->err == 1062 );
}

sub user_authorized {
    my ( $self, $user, $api_key ) = @_;

    my $dbh = $self->dbh;
    my ( $count ) = $dbh->selectrow_array(
        "SELECT count(*) FROM users WHERE username = ? AND api_key = ?",
        undef,
        $user,
        $api_key
    );

    return $count;
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
            (SELECT count(*) FROM result_entries JOIN test_results ON result_entries.hash_id = test_results.hash_id AND level = ?) AS nb_critical,
            (SELECT count(*) FROM result_entries JOIN test_results ON result_entries.hash_id = test_results.hash_id AND level = ?) AS nb_error,
            (SELECT count(*) FROM result_entries JOIN test_results ON result_entries.hash_id = test_results.hash_id AND level = ?) AS nb_warning,
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

no Moose;
__PACKAGE__->meta()->make_immutable();

1;
