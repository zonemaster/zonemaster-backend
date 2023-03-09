package Zonemaster::Backend::DB::PostgreSQL;

our $VERSION = '1.1.0';

use Moose;
use 5.14.2;

use DBI qw(:utils);
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
                id BIGSERIAL PRIMARY KEY,
                hash_id VARCHAR(16) NOT NULL,
                domain VARCHAR(255) NOT NULL,
                batch_id integer,
                created_at TIMESTAMP NOT NULL,
                started_at TIMESTAMP DEFAULT NULL,
                ended_at TIMESTAMP DEFAULT NULL,
                priority integer DEFAULT 10,
                queue integer DEFAULT 0,
                progress integer DEFAULT 0,
                fingerprint varchar(32),
                params json NOT NULL,
                undelegated integer NOT NULL DEFAULT 0,
                results json,

                UNIQUE (hash_id)
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
                created_at TIMESTAMP NOT NULL
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
                api_key VARCHAR(512),

                UNIQUE (username)
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

sub add_batch_job {
    my ( $self, $params ) = @_;
    my $batch_id;

    my $dbh = $self->dbh;

    if ( $self->user_authorized( $params->{username}, $params->{api_key} ) ) {
        $batch_id = $self->create_new_batch_job( $params->{username} );

        my $job_params  = $params->{job_params};

        my $priority    = $job_params->{priority};
        my $queue_label = $job_params->{queue};

        my $created_at = $self->format_time( time() );

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
                    created_at,
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
            $job_params->{domain} = _normalize_domain( $domain );

            my $fingerprint = $self->generate_fingerprint( $job_params );
            my $encoded_params = $self->encode_params( $job_params );
            my $undelegated = $self->undelegated ( $job_params );

            my $hash_id = substr(md5_hex(time().rand()), 0, 16);
            $dbh->pg_putcopydata(
                "$hash_id\t$job_params->{domain}\t$batch_id\t$created_at\t$priority\t$queue_label\t$fingerprint\t$encoded_params\t$undelegated\n"
            );
        }
        $dbh->pg_putcopyend();
        $dbh->do( "ALTER TABLE test_results ADD PRIMARY KEY (id)" );
        $dbh->do( "CREATE INDEX test_results__hash_id ON test_results (hash_id, created_at)" );
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
            SELECT EXTRACT(EPOCH FROM ? - started_at)
            FROM test_results
            WHERE hash_id=?
        ],
        undef,
        $self->format_time( time() ),
        $hash_id,
    );
}

sub is_duplicate {
    my ( $self ) = @_;

    # for the list of codes see:
    # https://www.postgresql.org/docs/current/errcodes-appendix.html
    return ( $self->dbh->state == 23505 );
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;
