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

    my $dbh = $class->_new_dbh(
        $data_source_name,
        $user,
        $password,
    );

    return $class->new(
        {
            data_source_name => $data_source_name,
            user             => $user,
            password         => $password,
            dbhandle         => $dbh,
        }
    );
}


sub create_db {
    my ( $self ) = @_;

    my $dbh = $self->dbh;

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $dbh->do(
        'CREATE TABLE IF NOT EXISTS test_results (
            id integer AUTO_INCREMENT PRIMARY KEY,
            hash_id VARCHAR(16) NOT NULL,
            domain varchar(255) NOT NULL,
            batch_id integer NULL,
            creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
            test_start_time TIMESTAMP NULL DEFAULT NULL,
            test_end_time TIMESTAMP NULL DEFAULT NULL,
            priority integer DEFAULT 10,
            queue integer DEFAULT 0,
            progress integer DEFAULT 0,
            fingerprint character varying(32),
            params blob NOT NULL,
            results mediumblob DEFAULT NULL,
            undelegated integer NOT NULL DEFAULT 0
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
    # BATCH JOBS
    ####################################################################
    $dbh->do(
        'CREATE TABLE IF NOT EXISTS batch_jobs (
            id integer AUTO_INCREMENT PRIMARY KEY,
            username character varying(50) NOT NULL,
            creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
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
            api_key varchar(512)
        ) ENGINE=InnoDB;
        '
    ) or die Zonemaster::Backend::Error::Internal->new( reason => "MySQL error, could not create 'users' table", data => $dbh->errstr() );
}

sub recent_test_hash_id {
    my ( $self, $age_reuse_previous_test, $fingerprint ) = @_;

    my $dbh = $self->dbh;
    my ( $recent_hash_id ) = $dbh->selectrow_array(
        "SELECT hash_id FROM test_results WHERE fingerprint = ? AND (TO_SECONDS(NOW()) - TO_SECONDS(creation_time)) < ?",
        undef, $fingerprint, $age_reuse_previous_test
    );

    return $recent_hash_id;
}

sub test_progress {
    my ( $self, $test_id, $progress ) = @_;

    my $dbh = $self->dbh;
    if ( $progress ) {
        if ($progress == 1) {
            $dbh->do( "UPDATE test_results SET progress=?, test_start_time=NOW() WHERE hash_id=? AND progress <> 100", undef, $progress, $test_id );
        }
        else {
            $dbh->do( "UPDATE test_results SET progress=? WHERE hash_id=? AND progress <> 100", undef, $progress, $test_id );
        }
    }

    my ( $result ) = $self->dbh->selectrow_array( "SELECT progress FROM test_results WHERE hash_id=?", undef, $test_id );

    return $result;
}

sub test_results {
    my ( $self, $test_id, $new_results ) = @_;

    if ( $new_results ) {
        $self->dbh->do( qq[UPDATE test_results SET progress=100, test_end_time=NOW(), results = ? WHERE hash_id=? AND progress < 100],
            undef, $new_results, $test_id );
    }

    my $result;
    my ( $hrefs ) = $self->dbh->selectall_hashref( "SELECT id, hash_id, CONVERT_TZ(`creation_time`, \@\@session.time_zone, '+00:00') AS creation_time, params, results FROM test_results WHERE hash_id=?", 'hash_id', undef, $test_id );
    $result            = $hrefs->{$test_id};

    die Zonemaster::Backend::Error::ResourceNotFound->new( message => "Test not found", data => { test_id => $test_id } )
        unless defined $result;

    eval {
        $result->{params}  = _decode_json_sanitize( $result->{params} );

        if (defined $result->{results}) {
            $result->{results} = _decode_json_sanitize( $result->{results} );
        } else {
            $result->{results} = [];
        }
    };

    die Zonemaster::Backend::Error::JsonError->new( reason => "$@", data => { test_id => $test_id } )
        if $@;

    return $result;
}

sub get_test_history {
    my ( $self, $p ) = @_;

    my @results;
    my $sth = {};

    my $undelegated = "";
    if ($p->{filter} eq "undelegated") {
        $undelegated = 1;
    } elsif ($p->{filter} eq "delegated") {
        $undelegated = 0;
    }

    if ($p->{filter} eq "all") {
        $sth = $self->dbh->prepare(
            q[SELECT
                id,
                hash_id,
                CONVERT_TZ(`creation_time`, @@session.time_zone, '+00:00') AS creation_time,
                params,
                undelegated,
                results
            FROM
                test_results
            WHERE
                domain = ?
            ORDER BY id DESC
            LIMIT ? OFFSET ?]
        );
        $sth->execute( $p->{frontend_params}{domain}, $p->{limit}, $p->{offset} );
    } else {
        $sth = $self->dbh->prepare(
            q[SELECT
                id,
                hash_id,
                CONVERT_TZ(`creation_time`, @@session.time_zone, '+00:00') AS creation_time,
                params,
                undelegated,
                results
            FROM
                test_results
            WHERE
                domain = ?
                AND undelegated = ?
            ORDER BY id DESC
            LIMIT ? OFFSET ?]
        );
        $sth->execute( $p->{frontend_params}{domain}, $undelegated, $p->{limit}, $p->{offset} );
    }

    while ( my $h = $sth->fetchrow_hashref ) {
        $h->{results} = decode_json($h->{results}) if $h->{results};
        $h->{params} = decode_json($h->{params}) if $h->{params};
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
        eval {$dbh->do( "DROP INDEX test_results__hash_id ON test_results" );};
        eval {$dbh->do( "DROP INDEX test_results__fingerprint ON test_results" );};
        eval {$dbh->do( "DROP INDEX test_results__batch_id_progress ON test_results" );};
        eval {$dbh->do( "DROP INDEX test_results__progress ON test_results" );};
        eval {$dbh->do( "DROP INDEX test_results__domain_undelegated ON test_results" );};

        my $sth = $dbh->prepare( 'INSERT INTO test_results (hash_id, domain, batch_id, priority, queue, fingerprint, params, undelegated) VALUES (?,?,?,?,?,?,?,?)' );
        foreach my $domain ( @{$params->{domains}} ) {
            $test_params->{domain} = $domain;

            my $fingerprint = $self->generate_fingerprint( $test_params );
            my $encoded_params = $self->encode_params( $test_params );
            my $undelegated = $self->undelegated ( $test_params );

            my $hash_id = substr(md5_hex(time().rand()), 0, 16);
            $sth->execute( $hash_id, $test_params->{domain}, $batch_id, $priority, $queue_label, $fingerprint, $encoded_params, $undelegated );
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

sub select_unfinished_tests {
    my ( $self, $queue_label, $test_run_timeout ) = @_;

    if ( $queue_label ) {
        my $sth = $self->dbh->prepare( "
            SELECT hash_id, results
            FROM test_results
            WHERE test_start_time < DATE_SUB(NOW(), INTERVAL ? SECOND)
            AND progress > 0
            AND progress < 100
            AND queue = ?" );
        $sth->execute(    #
            $test_run_timeout,
            $queue_label,
        );
        return $sth;
    }
    else {
        my $sth = $self->dbh->prepare( "
            SELECT hash_id, results
            FROM test_results
            WHERE test_start_time < DATE_SUB(NOW(), INTERVAL ? SECOND)
            AND progress > 0
            AND progress < 100" );
        $sth->execute(    #
            $test_run_timeout,
        );
        return $sth;
    }
}

sub process_unfinished_tests_give_up {
    my ( $self, $result, $hash_id ) = @_;

    $self->dbh->do("UPDATE test_results SET progress = 100, test_end_time = NOW(), results = ? WHERE hash_id=?", undef, encode_json($result), $hash_id);
}

sub get_relative_start_time {
    my ( $self, $hash_id ) = @_;

    return $self->dbh->selectrow_array("SELECT now() - test_start_time FROM test_results WHERE hash_id=?", undef, $hash_id);
}


no Moose;
__PACKAGE__->meta()->make_immutable();

1;
