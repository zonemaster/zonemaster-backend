package Zonemaster::Backend::DB::MySQL;

our $VERSION = '1.1.0';

use Moose;
use 5.14.2;

use DBI qw(:utils);
use Digest::MD5 qw(md5_hex);
use JSON::PP;

use Zonemaster::Backend::Validator qw( untaint_ipv6_address );
use Zonemaster::Backend::Errors;

with 'Zonemaster::Backend::DB';

=head1 CLASS METHODS

=head2 from_config

Construct a new instance from a Zonemaster::Backend::Config.

    my $db = Zonemaster::Backend::DB::MySQL->from_config( $config );

=cut

sub from_config {
    my ( $class, $config ) = @_;

    my $database = $config->MYSQL_database;
    my $host     = $config->MYSQL_host;
    my $port     = $config->MYSQL_port;
    my $user     = $config->MYSQL_user;
    my $password = $config->MYSQL_password;

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

sub create_schema {
    my ( $self ) = @_;

    my $dbh = $self->dbh;

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $dbh->do(
        'CREATE TABLE IF NOT EXISTS test_results (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            hash_id VARCHAR(16) NOT NULL,
            domain varchar(255) NOT NULL,
            batch_id integer NULL,
            created_at DATETIME NOT NULL,
            started_at DATETIME DEFAULT NULL,
            ended_at DATETIME DEFAULT NULL,
            priority integer DEFAULT 10,
            queue integer DEFAULT 0,
            progress integer DEFAULT 0,
            fingerprint character varying(32),
            params blob NOT NULL,
            results mediumblob DEFAULT NULL,
            undelegated integer NOT NULL DEFAULT 0,

            UNIQUE (hash_id)
        ) ENGINE=InnoDB
        '
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "MySQL error, could not create 'test_results' table", data => $dbh->errstr() );

    # Manually create the index if it does not exist
    # the clause IF NOT EXISTS is not available for MySQL (used with FreeBSD)

    # retrieve all indexes by key name
    my $indexes = $dbh->selectall_hashref( 'SHOW INDEXES FROM test_results', 'Key_name' );

    if ( not exists($indexes->{test_results__hash_id}) ) {
        $dbh->do(
            'CREATE INDEX test_results__hash_id ON test_results (hash_id)'
        );
    }
    if ( not exists($indexes->{test_results__fingerprint}) ) {
        $dbh->do(
            'CREATE INDEX test_results__fingerprint ON test_results (fingerprint)'
        );
    }
    if ( not exists($indexes->{test_results__batch_id_progress}) ) {
        $dbh->do(
            'CREATE INDEX test_results__batch_id_progress ON test_results (batch_id, progress)'
        );
    }
    if ( not exists($indexes->{test_results__progress}) ) {
        $dbh->do(
            'CREATE INDEX test_results__progress ON test_results (progress)'
        );
    }
    if ( not exists($indexes->{test_results__domain_undelegated}) ) {
        $dbh->do(
            'CREATE INDEX test_results__domain_undelegated ON test_results (domain, undelegated)'
        );
    }

    ####################################################################
    # RESULT ENTRIES
    ####################################################################
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS result_entries (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            hash_id VARCHAR(16) NOT NULL,
            level ENUM ('DEBUG3', 'DEBUG2', 'DEBUG', 'INFO', 'NOTICE', 'WARNING', 'ERROR', 'CRITICAL') NOT NULL,
            module VARCHAR(255) NOT NULL,
            testcase VARCHAR(255) NOT NULL,
            tag VARCHAR(255) NOT NULL,
            timestamp REAL NOT NULL,
            args BLOB NOT NULL
        ) ENGINE=InnoDB
        "
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "MySQL error, could not create 'result_entries' table", data => $dbh->errstr() );

    $indexes = $dbh->selectall_hashref( 'SHOW INDEXES FROM result_entries', 'Key_name' );
    if ( not exists($indexes->{result_entries__hash_id}) ) {
        $dbh->do(
            'CREATE INDEX result_entries__hash_id ON result_entries (hash_id)'
        );
    }

    if ( not exists($indexes->{result_entries__level}) ) {
        $dbh->do(
            'CREATE INDEX result_entries__level ON result_entries (level)'
        );
    }


    ####################################################################
    # BATCH JOBS
    ####################################################################
    $dbh->do(
        'CREATE TABLE IF NOT EXISTS batch_jobs (
            id integer AUTO_INCREMENT PRIMARY KEY,
            username character varying(50) NOT NULL,
            created_at DATETIME NOT NULL
        ) ENGINE=InnoDB;
        '
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "MySQL error, could not create 'batch_jobs' table", data => $dbh->errstr() );


    ####################################################################
    # USERS
    ####################################################################
    $dbh->do(
        'CREATE TABLE IF NOT EXISTS users (
            id integer AUTO_INCREMENT primary key,
            username varchar(128),
            api_key varchar(512),

            UNIQUE (username)
        ) ENGINE=InnoDB;
        '
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "MySQL error, could not create 'users' table", data => $dbh->errstr() );

    return;
}

=head2 drop_tables

Drop all the tables if they exist.

=cut

sub drop_tables {
    my ( $self ) = @_;

    $self->dbh->do( "DROP TABLE IF EXISTS test_results" );
    $self->dbh->do( "DROP TABLE IF EXISTS result_entries" );
    $self->dbh->do( "DROP TABLE IF EXISTS users" );
    $self->dbh->do( "DROP TABLE IF EXISTS batch_jobs" );

    return;
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
        eval {$dbh->do( "DROP INDEX test_results__hash_id ON test_results" );};
        eval {$dbh->do( "DROP INDEX test_results__fingerprint ON test_results" );};
        eval {$dbh->do( "DROP INDEX test_results__batch_id_progress ON test_results" );};
        eval {$dbh->do( "DROP INDEX test_results__progress ON test_results" );};
        eval {$dbh->do( "DROP INDEX test_results__domain_undelegated ON test_results" );};

        my $sth = $dbh->prepare(
            q[
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
                ) VALUES (?,?,?,?,?,?,?,?,?)
            ],
        );
        foreach my $domain ( @{$params->{domains}} ) {
            $test_params->{domain} = _normalize_domain( $domain );

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
        $dbh->do( "CREATE INDEX test_results__hash_id ON test_results (hash_id, created_at)" );
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
            SELECT ? - started_at
            FROM test_results
            WHERE hash_id = ?
        ],
        undef,
        $self->format_time( time() ),
        $hash_id,
    );
}

sub is_duplicate {
    my ( $self ) = @_;

    # for the list of codes see:
    # https://mariadb.com/kb/en/mariadb-error-codes/
    # https://dev.mysql.com/doc/mysql-errors/8.0/en/server-error-reference.html
    return ( $self->dbh->err == 1062 );
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;
