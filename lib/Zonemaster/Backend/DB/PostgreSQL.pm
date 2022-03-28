package Zonemaster::Backend::DB::PostgreSQL;

our $VERSION = '1.1.0';

use Moose;
use 5.14.2;

use DBI qw(:utils :sql_types);
use Digest::MD5 qw(md5_hex);
use JSON::PP;
use Try::Tiny;

use Zonemaster::Backend::DB;
use Zonemaster::Backend::Errors;

with 'Zonemaster::Backend::DB';

=head1 CLASS METHODS

=head2 from_config

Construct a new instance from a Zonemaster::Backend::Config.

    my $db = Zonemaster::Backend::DB::PostgreSQL->from_config( $config );

=cut

sub from_config {
    my ( $class, $config ) = @_;

    my $database = $config->POSTGRESQL_database;
    my $host     = $config->POSTGRESQL_host;
    my $port     = $config->POSTGRESQL_port;
    my $user     = $config->POSTGRESQL_user;
    my $password = $config->POSTGRESQL_password;

    my $data_source_name = "DBI:Pg:dbname=$database;host=$host;port=$port";

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
    return { pg_enable_utf8 => 0 };
}

sub create_schema {
    my ( $self ) = @_;

    my $dbh = $self->dbh;

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $dbh->do(
        'CREATE TABLE IF NOT EXISTS test_results (
                id serial PRIMARY KEY,
                hash_id VARCHAR(16) NOT NULL,
                domain VARCHAR(255) NOT NULL,
                batch_id integer,
                creation_time TIMESTAMP NOT NULL,
                test_start_time TIMESTAMP DEFAULT NULL,
                test_end_time TIMESTAMP DEFAULT NULL,
                priority integer DEFAULT 10,
                queue integer DEFAULT 0,
                progress integer DEFAULT 0,
                fingerprint varchar(32),
                params json NOT NULL,
                undelegated integer NOT NULL DEFAULT 0,
                results json
            )
        '
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "PostgreSQL error, could not create 'test_results' table", data => $dbh->errstr() );

    $dbh->do(
        'CREATE INDEX IF NOT EXISTS test_results__hash_id ON test_results (hash_id)'
    );
    $dbh->do(
        'CREATE INDEX IF NOT EXISTS test_results__fingerprint ON test_results (fingerprint)'
    );
    $dbh->do(
        'CREATE INDEX IF NOT EXISTS test_results__batch_id_progress ON test_results (batch_id, progress)'
    );
    $dbh->do(
        'CREATE INDEX IF NOT EXISTS test_results__progress ON test_results (progress)'
    );
    $dbh->do(
        'CREATE INDEX IF NOT EXISTS test_results__domain_undelegated ON test_results (domain, undelegated)'
    );
    # this index helps speed up query time to retrieve the next test to
    # perform when using batches
    $dbh->do(
        'CREATE INDEX IF NOT EXISTS test_results__progress_priority_id ON test_results (progress, priority DESC, id) WHERE (progress = 0)'
    );


    ####################################################################
    # BATCH JOBS
    ####################################################################
    $dbh->do(
        'CREATE TABLE IF NOT EXISTS batch_jobs (
                id serial PRIMARY KEY,
                username varchar(50) NOT NULL,
                creation_time TIMESTAMP NOT NULL
            )
        '
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "PostgreSQL error, could not create 'batch_jobs' table", data => $dbh->errstr() );


    ####################################################################
    # USERS
    ####################################################################
    $dbh->do(
        'CREATE TABLE IF NOT EXISTS users (
                id serial PRIMARY KEY,
                username VARCHAR(128),
                api_key VARCHAR(512)
            )
        '
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "PostgreSQL error, could not create 'users' table", data => $dbh->errstr() );

    return;
}

=head2 drop_tables

Drop all the tables if they exist.

=cut

sub drop_tables {
    my ( $self ) = @_;

    # Temporarily set the message level just above "notice" to mute messages when the tables don't
    # exist.
    # Without setting this level we run the risk of tripping up Test::NoWarnings in unit tests.
    my ( $old_client_min_messages ) = $self->dbh->selectrow_array( "SHOW client_min_messages" );
    $self->dbh->do( "SET client_min_messages = warning" );

    try {
        $self->dbh->do( "DROP TABLE IF EXISTS test_results" );
        $self->dbh->do( "DROP TABLE IF EXISTS users" );
        $self->dbh->do( "DROP TABLE IF EXISTS batch_jobs" );
    }
    finally {
        $self->dbh->do( "SET client_min_messages = ?", undef, $old_client_min_messages );
    };

    return;
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
            (SELECT count(*) FROM (SELECT json_array_elements(results) AS result) AS t1 WHERE result->>'level'='CRITICAL') AS nb_critical,
            (SELECT count(*) FROM (SELECT json_array_elements(results) AS result) AS t1 WHERE result->>'level'='ERROR') AS nb_error,
            (SELECT count(*) FROM (SELECT json_array_elements(results) AS result) AS t1 WHERE result->>'level'='WARNING') AS nb_warning,
            id,
            hash_id,
            undelegated,
            creation_time
        FROM test_results
        WHERE progress = 100 AND domain = ? AND ( ? IS NULL OR undelegated = ? )
        ORDER BY id DESC
        LIMIT ?
        OFFSET ?];

    my $sth1 = $dbh->prepare( $query );

    $sth1->bind_param( 1, $p->{frontend_params}{domain} );
    $sth1->bind_param( 2, $undelegated, SQL_INTEGER );
    $sth1->bind_param( 3, $undelegated, SQL_INTEGER );
    $sth1->bind_param( 4, $p->{limit} );
    $sth1->bind_param( 5, $p->{offset} );

    $sth1->execute();

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
                id               => $h->{hash_id},
                creation_time    => $h->{creation_time},
                created_at       => $self->to_iso8601( $h->{creation_time} ),
                undelegated      => $h->{undelegated},
                overall_result   => $overall_result,
            }
        );
    }

    return \@results;
}

sub add_batch_job {
    my ( $self, $params ) = @_;
    my $batch_id;

    my $dbh = $self->dbh;

    if ( $self->user_authorized( $params->{username}, $params->{api_key} ) ) {
        $batch_id = $self->create_new_batch_job( $params->{username} );

        my $test_params = $params->{test_params};

        my $priority    = $test_params->{priority};
        my $queue_label = $test_params->{queue};

        my $creation_time = $self->format_time( time() );

        $dbh->begin_work();
        $dbh->do( "ALTER TABLE test_results DROP CONSTRAINT IF EXISTS test_results_pkey" );
        $dbh->do( "DROP INDEX IF EXISTS test_results__hash_id" );
        $dbh->do( "DROP INDEX IF EXISTS test_results__fingerprint" );
        $dbh->do( "DROP INDEX IF EXISTS test_results__batch_id_progress" );
        $dbh->do( "DROP INDEX IF EXISTS test_results__progress" );
        $dbh->do( "DROP INDEX IF EXISTS test_results__domain_undelegated" );

        $dbh->do(
            q[
                COPY test_results (
                    hash_id,
                    domain,
                    batch_id,
                    creation_time,
                    priority,
                    queue,
                    fingerprint,
                    params,
                    undelegated
                )
                FROM STDIN
            ]
        );

        foreach my $domain ( @{$params->{domains}} ) {
            $test_params->{domain} = $domain;

            my $fingerprint = $self->generate_fingerprint( $test_params );
            my $encoded_params = $self->encode_params( $test_params );
            my $undelegated = $self->undelegated ( $test_params );

            my $hash_id = substr(md5_hex(time().rand()), 0, 16);
            $dbh->pg_putcopydata(
                "$hash_id\t$test_params->{domain}\t$batch_id\t$creation_time\t$priority\t$queue_label\t$fingerprint\t$encoded_params\t$undelegated\n"
            );
        }
        $dbh->pg_putcopyend();
        $dbh->do( "ALTER TABLE test_results ADD PRIMARY KEY (id)" );
        $dbh->do( "CREATE INDEX test_results__hash_id ON test_results (hash_id, creation_time)" );
        $dbh->do( "CREATE INDEX test_results__fingerprint ON test_results (fingerprint)" );
        $dbh->do( "CREATE INDEX test_results__batch_id_progress ON test_results (batch_id, progress)" );
        $dbh->do( "CREATE INDEX test_results__progress ON test_results (progress)" );
        $dbh->do( "CREATE INDEX test_results__domain_undelegated ON test_results (domain, undelegated)" );

        $dbh->commit();
    }
    else {
        die Zonemaster::Backend::Error::PermissionDenied->new( message => 'User not authorized to use batch mode', data => { username => $params->{username}} );
    }

    return $batch_id;
}

sub get_relative_start_time {
    my ( $self, $hash_id ) = @_;

    return $self->dbh->selectrow_array(
        q[
            SELECT EXTRACT(EPOCH FROM ? - test_start_time)
            FROM test_results
            WHERE hash_id=?
        ],
        undef,
        $self->format_time( time() ),
        $hash_id,
    );
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;
