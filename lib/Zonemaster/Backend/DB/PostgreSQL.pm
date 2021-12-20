package Zonemaster::Backend::DB::PostgreSQL;

our $VERSION = '1.1.0';

use Moose;
use 5.14.2;

use DBI qw(:utils);
use Digest::MD5 qw(md5_hex);
use Encode;
use JSON::PP;

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
                id serial PRIMARY KEY,
                hash_id VARCHAR(16) NOT NULL,
                domain VARCHAR(255) NOT NULL,
                batch_id integer,
                creation_time timestamp without time zone DEFAULT NOW() NOT NULL,
                test_start_time timestamp without time zone DEFAULT NULL,
                test_end_time timestamp without time zone DEFAULT NULL,
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
                creation_time timestamp without time zone DEFAULT NOW() NOT NULL
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

}

sub recent_test_hash_id {
    my ( $self, $age_reuse_previous_test, $fingerprint ) = @_;

    my $dbh = $self->dbh;
    my ( $recent_hash_id ) = $dbh->selectrow_array(
        "SELECT hash_id FROM test_results WHERE fingerprint = ? AND creation_time > NOW() - ?::interval",
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

    my ( $result ) = $dbh->selectrow_array( "SELECT progress FROM test_results WHERE hash_id=?", undef, $test_id );

    return $result;
}

sub test_results {
    my ( $self, $test_id, $results ) = @_;

    my $dbh = $self->dbh;
    $dbh->do( "UPDATE test_results SET progress=100, test_end_time=NOW(), results = ? WHERE hash_id=? AND progress < 100",
        undef, $results, $test_id )
      if ( $results );

    my $result;
    my ( $hrefs ) = $dbh->selectall_hashref( "SELECT id, hash_id, creation_time at time zone current_setting('TIMEZONE') at time zone 'UTC' as creation_time, params, results FROM test_results WHERE hash_id=?", 'hash_id', undef, $test_id );
    $result = $hrefs->{$test_id};

    die Zonemaster::Backend::Error::ResourceNotFound->new( message => "Test not found", data => { test_id => $test_id } )
        unless defined $result;

    eval {
        $result->{params} = _decode_json_sanitize( $result->{params} );

        if (defined $result->{results} ) {
            $result->{results} = _decode_json_sanitize( $result->{results} );
        } else {
            $result->{results} = [];
        }
    };

    die Zonemaster::Backend::Error::JsonError->new( reason => "$@", data => { test_id => $test_id })
        if $@;

    return $result;
}

sub get_test_history {
    my ( $self, $p ) = @_;

    my $dbh = $self->dbh;

    my $undelegated = "";
    if ($p->{filter} eq "undelegated") {
        $undelegated = "AND undelegated = 1";
    } elsif ($p->{filter} eq "delegated") {
        $undelegated = "AND undelegated = 0";
    }

    my @results;
    my $query = "
        SELECT
            (SELECT count(*) FROM (SELECT json_array_elements(results) AS result) AS t1 WHERE result->>'level'='CRITICAL') AS nb_critical,
            (SELECT count(*) FROM (SELECT json_array_elements(results) AS result) AS t1 WHERE result->>'level'='ERROR') AS nb_error,
            (SELECT count(*) FROM (SELECT json_array_elements(results) AS result) AS t1 WHERE result->>'level'='WARNING') AS nb_warning,
            id,
            hash_id,
            undelegated,
            creation_time at time zone current_setting('TIMEZONE') at time zone 'UTC' as creation_time
        FROM test_results
        WHERE domain=" . $dbh->quote( $p->{frontend_params}->{domain} ) . " $undelegated
        ORDER BY id DESC
        OFFSET $p->{offset} LIMIT $p->{limit}";
    my $sth1 = $dbh->prepare( $query );
    $sth1->execute;
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

        $dbh->begin_work();
        $dbh->do( "ALTER TABLE test_results DROP CONSTRAINT IF EXISTS test_results_pkey" );
        $dbh->do( "DROP INDEX IF EXISTS test_results__hash_id" );
        $dbh->do( "DROP INDEX IF EXISTS test_results__fingerprint" );
        $dbh->do( "DROP INDEX IF EXISTS test_results__batch_id_progress" );
        $dbh->do( "DROP INDEX IF EXISTS test_results__progress" );
        $dbh->do( "DROP INDEX IF EXISTS test_results__domain_undelegated" );

        $dbh->do( "COPY test_results(hash_id,domain ,batch_id, priority, queue, fingerprint, params, undelegated) FROM STDIN" );
        foreach my $domain ( @{$params->{domains}} ) {
            $test_params->{domain} = $domain;

            my $fingerprint = $self->generate_fingerprint( $test_params );
            my $encoded_params = $self->encode_params( $test_params );
            my $undelegated = $self->undelegated ( $test_params );

            my $hash_id = substr(md5_hex(time().rand()), 0, 16);
            $dbh->pg_putcopydata("$hash_id\t$test_params->{domain}\t$batch_id\t$priority\t$queue_label\t$fingerprint\t$encoded_params\t$undelegated\n");
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

sub select_unfinished_tests {
    my ( $self, $queue_label, $test_run_timeout ) = @_;

    if ( $queue_label ) {
        my $sth = $self->dbh->prepare( "
            SELECT hash_id, results
            FROM test_results
            WHERE test_start_time < NOW() - ?::interval
            AND progress > 0
            AND progress < 100
            AND queue = ?" );
        $sth->execute(    #
            sprintf( "%d seconds", $test_run_timeout ),
            $queue_label,
        );
        return $sth;
    }
    else {
        my $sth = $self->dbh->prepare( "
            SELECT hash_id, results
            FROM test_results
            WHERE test_start_time < NOW() - ?::interval
            AND progress > 0
            AND progress < 100" );
        $sth->execute(    #
            sprintf( "%d seconds", $test_run_timeout ),
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

    return $self->dbh->selectrow_array("SELECT EXTRACT(EPOCH FROM now() - test_start_time) FROM test_results WHERE hash_id=?", undef, $hash_id);
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;
