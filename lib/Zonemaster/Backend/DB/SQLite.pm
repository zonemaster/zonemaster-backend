package Zonemaster::Backend::DB::SQLite;

our $VERSION = '1.1.0';

use Moose;
use 5.14.2;

use DBI qw(:utils :sql_types);
use Digest::MD5 qw(md5_hex);
use JSON::PP;

use Zonemaster::Backend::Errors;

with 'Zonemaster::Backend::DB';

=head1 CLASS METHODS

=head2 from_config

Construct a new instance from a Zonemaster::Backend::Config.

    my $db = Zonemaster::Backend::DB::SQLite->from_config( $config );

=cut

sub from_config {
    my ( $class, $config ) = @_;

    my $file = $config->SQLITE_database_file;

    my $data_source_name = "DBI:SQLite:dbname=$file";

    return $class->new(
        {
            data_source_name => $data_source_name,
            user             => '',
            password         => '',
            dbhandle         => undef,
        }
    );
}

sub DEMOLISH {
    my ( $self ) = @_;
    $self->dbh->disconnect() if defined $self->dbhandle && $self->dbhandle->ping;
}

sub get_dbh_specific_attributes {
    return {};
}

sub create_schema {
    my ( $self ) = @_;

    my $dbh = $self->dbh;

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $dbh->do(
        'CREATE TABLE IF NOT EXISTS test_results (
                 id integer PRIMARY KEY AUTOINCREMENT,
                 hash_id VARCHAR(16) NOT NULL,
                 domain VARCHAR(255) NOT NULL,
                 batch_id integer NULL,
                 creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                 test_start_time TIMESTAMP DEFAULT NULL,
                 test_end_time TIMESTAMP DEFAULT NULL,
                 priority integer DEFAULT 10,
                 queue integer DEFAULT 0,
                 progress integer DEFAULT 0,
                 fingerprint character varying(32),
                 params text NOT NULL,
                 results text DEFAULT NULL,
                 undelegated boolean NOT NULL DEFAULT false
           )
        '
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "SQLite error, could not create 'test_results' table", data => $dbh->errstr() );

    $dbh->do(
        'CREATE INDEX IF NOT EXISTS test_results__hash_id ON test_results (hash_id)'
    );
    $self->dbh->do(
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


    ####################################################################
    # BATCH JOBS
    ####################################################################
    $dbh->do(
        'CREATE TABLE IF NOT EXISTS batch_jobs (
                 id integer PRIMARY KEY,
                 username character varying(50) NOT NULL,
                 creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
           )
        '
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "SQLite error, could not create 'batch_jobs' table", data => $dbh->errstr() );


    ####################################################################
    # USERS
    ####################################################################
    $dbh->do(
        'CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username varchar(128),
                api_key varchar(512)
           )
        '
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "SQLite error, could not create 'users' table", data => $dbh->errstr() );

    return;
}

=head2 drop_tables

Drop all the tables if they exist.

=cut

sub drop_tables {
    my ( $self ) = @_;

    $self->dbh->do( "DROP TABLE IF EXISTS test_results" );
    $self->dbh->do( "DROP TABLE IF EXISTS users" );
    $self->dbh->do( "DROP TABLE IF EXISTS batch_jobs" );

    return;
}

sub select_test_results {
    my ( $self, $test_id ) = @_;

    my ( $hrefs ) = $self->dbh->selectall_hashref(
        q[
            SELECT
                id,
                hash_id,
                creation_time,
                params,
                results
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
            id,
            hash_id,
            creation_time,
            undelegated,
            results
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
        $h->{results} = decode_json($h->{results}) if $h->{results};
        my $critical = ( grep { $_->{level} eq 'CRITICAL' } @{ $h->{results} } );
        my $error    = ( grep { $_->{level} eq 'ERROR' } @{ $h->{results} } );
        my $warning  = ( grep { $_->{level} eq 'WARNING' } @{ $h->{results} } );

        # More important overwrites
        my $overall = 'ok';
        $overall = 'warning'  if $warning;
        $overall = 'error'    if $error;
        $overall = 'critical' if $critical;
        push(
            @results,
            {
                id               => $h->{hash_id},
                creation_time    => $h->{creation_time},
                undelegated      => $h->{undelegated},
                overall_result   => $overall,
            }
            );
    }
    $sth1->finish;

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

        $dbh->{AutoCommit} = 0;
        eval {$dbh->do( "DROP INDEX IF EXISTS test_results__hash_id " );};
        eval {$dbh->do( "DROP INDEX IF EXISTS test_results__fingerprint " );};
        eval {$dbh->do( "DROP INDEX IF EXISTS test_results__batch_id_progress " );};
        eval {$dbh->do( "DROP INDEX IF EXISTS test_results__progress " );};
        eval {$dbh->do( "DROP INDEX IF EXISTS test_results__domain_undelegated " );};

        my $sth = $dbh->prepare( '
            INSERT INTO test_results (
                hash_id,
                domain,
                batch_id,
                creation_time,
                priority,
                queue,
                fingerprint,
                params,
                undelegated
            ) VALUES (?,?,?,?,?,?,?,?,?)'
        );
        foreach my $domain ( @{$params->{domains}} ) {
            $test_params->{domain} = $domain;

            my $fingerprint = $self->generate_fingerprint( $test_params );
            my $encoded_params = $self->encode_params( $test_params );
            my $undelegated = $self->undelegated ( $test_params );

            my $hash_id = substr(md5_hex(time().rand()), 0, 16);
            $sth->execute(
                $hash_id,
                $test_params->{domain},
                $batch_id,
                $self->format_time( time() ),
                $priority,
                $queue_label,
                $fingerprint,
                $encoded_params,
                $undelegated,
            );
        }
        $dbh->do( "CREATE INDEX test_results__hash_id ON test_results (hash_id, creation_time)" );
        $dbh->do( "CREATE INDEX test_results__fingerprint ON test_results (fingerprint)" );
        $dbh->do( "CREATE INDEX test_results__batch_id_progress ON test_results (batch_id, progress)" );
        $dbh->do( "CREATE INDEX test_results__progress ON test_results (progress)" );
        $dbh->do( "CREATE INDEX test_results__domain_undelegated ON test_results (domain, undelegated)" );

        $dbh->commit();
        $dbh->{AutoCommit} = 1;
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
            SELECT (julianday(?) - julianday(test_start_time)) * 3600 * 24
            FROM test_results
            WHERE hash_id = ?
        ],
        undef,
        $self->format_time( time() ),
        $hash_id,
    );
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;
