package Zonemaster::Backend::DB::SQLite;

our $VERSION = '1.1.0';

use Moose;
use 5.14.2;

use Data::Dumper;
use DBI qw(:utils);
use Digest::MD5 qw(md5_hex);
use JSON::PP;
use Log::Any qw( $log );

use Zonemaster::Backend::Errors;

with 'Zonemaster::Backend::DB';

has 'dbh' => (
    is  => 'rw',
    isa => 'DBI::db',
);

=head1 CLASS METHODS

=head2 from_config

Construct a new instance from a Zonemaster::Backend::Config.

    my $db = Zonemaster::Backend::DB::SQLite->from_config( $config );

=cut

sub from_config {
    my ( $class, $config ) = @_;

    my $file = $config->SQLITE_database_file;

    my $data_source_name = "DBI:SQLite:dbname=$file";

    my $dbh = $class->_new_dbh( $data_source_name, '', '' );

    return $class->new(
        {
            dbh => $dbh,
        }
    );
}

sub DEMOLISH {
    my ( $self ) = @_;
    $self->dbh->disconnect() if $self->dbh;
}

sub create_db {
    my ( $self ) = @_;

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $self->dbh->do(
        'CREATE TABLE test_results (
                 id integer PRIMARY KEY AUTOINCREMENT,
                 hash_id VARCHAR(16) DEFAULT NULL,
                 domain VARCHAR(255) NOT NULL,
                 batch_id integer NULL,
                 creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                 test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                 test_end_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                 priority integer DEFAULT 10,
                 queue integer DEFAULT 0,
                 progress integer DEFAULT 0,
                 params_deterministic_hash character varying(32),
                 params text NOT NULL,
                 results text DEFAULT NULL,
                 undelegated boolean NOT NULL DEFAULT false,
                 nb_retries integer NOT NULL DEFAULT 0
           )
        '
    ) or die "SQLite Fatal error: " . $self->dbh->errstr() . "\n";

    $self->dbh->do(
        'CREATE INDEX test_results__hash_id ON test_results (hash_id)'
    );
    $self->dbh->do(
        'CREATE INDEX test_results__fingerprint ON test_results (params_deterministic_hash)'
    );
    $self->dbh->do(
        'CREATE INDEX test_results__batch_id_progress ON test_results (batch_id, progress)'
    );
    $self->dbh->do(
        'CREATE INDEX test_results__progress ON test_results (progress)'
    );
    $self->dbh->do(
        'CREATE INDEX test_results__domain_undelegated ON test_results (domain, undelegated)'
    );

    $dbh->do(
        'CREATE TABLE result_entries (
            id integer PRIMARY KEY AUTOINCREMENT,
            hash_id VARCHAR(16) not null,
            level varchar(15) not null,
            module varchar(255) not null,
            testcase varchar(255) not null,
            tag varchar(255) not null,
            timestamp real not null,
            args blob not null
        )
        '
    );

    $dbh->do(
        'CREATE INDEX result_entries__hash_id ON result_entries (hash_id)'
    );

    $dbh->do(
        'CREATE INDEX result_entries__level ON result_entries (level)'
    );

    ####################################################################
    # BATCH JOBS
    ####################################################################
    $self->dbh->do(
        'CREATE TABLE batch_jobs (
                 id integer PRIMARY KEY,
                 username character varying(50) NOT NULL,
                 creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
           )
        '
    ) or die "SQLite Fatal error: " . $self->dbh->errstr() . "\n";


    ####################################################################
    # USERS
    ####################################################################
    $self->dbh->do(
        'CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username varchar(128),
                api_key varchar(512),
                user_info json DEFAULT NULL
           )
        '
    ) or die "SQLite Fatal error: " . $self->dbh->errstr() . "\n";

    return 1;
}

sub user_exists_in_db {
    my ( $self, $user ) = @_;

    my ( $id ) = $self->dbh->selectrow_array( "SELECT id FROM users WHERE username = ?", undef, $user );

    return $id;
}

sub add_api_user_to_db {
    my ( $self, $user_name, $api_key  ) = @_;

    my $nb_inserted = $self->dbh->do(
        "INSERT INTO users (user_info, username, api_key) VALUES (?,?,?)",
        undef,
        'NULL',
        $user_name,
        $api_key,
    );

    return $nb_inserted;
}

sub user_authorized {
    my ( $self, $user, $api_key ) = @_;

    my ( $id ) =
      $self->dbh->selectrow_array( q[SELECT id FROM users WHERE username = ? AND api_key = ?], undef, $user, $api_key );

    return $id;
}

sub create_new_batch_job {
    my ( $self, $username ) = @_;

    my ( $batch_id, $creation_time ) = $self->dbh->selectrow_array( "
               SELECT
                    batch_id,
                    batch_jobs.creation_time AS batch_creation_time
               FROM
                    test_results
               JOIN batch_jobs
                    ON batch_id=batch_jobs.id
                    AND username=" . $self->dbh->quote( $username ) . " WHERE
                    test_results.progress<>100
               LIMIT 1
               " );

    die Zonemaster::Backend::Error::Conflict->new( message => 'Batch job still running', data => { batch_id => $batch_id, creation_time => $creation_time } )
        if ( $batch_id );

    $self->dbh->do("INSERT INTO batch_jobs (username) VALUES(" . $self->dbh->quote( $username ) . ")" );
    my ( $new_batch_id ) = $self->dbh->sqlite_last_insert_rowid;

    return $new_batch_id;
}

sub create_new_test {
    my ( $self, $domain, $test_params, $seconds, $batch_id ) = @_;

    my $dbh = $self->dbh;

    $test_params->{domain} = $domain;

    my $fingerprint = $self->generate_fingerprint( $test_params );
    my $encoded_params = $self->encode_params( $test_params );
    my $undelegated = $self->undelegated ( $test_params );

    my $result_id;

    my $priority    = $test_params->{priority};
    my $queue_label = $test_params->{queue};

    # Search for recent test result with the test same parameters, where "$seconds"
    # gives the time limit for how old test result that is accepted.
    my ( $recent_hash_id ) = $dbh->selectrow_array(
        "SELECT hash_id FROM test_results WHERE params_deterministic_hash = ? AND test_start_time > DATETIME('now', ?)",
        undef,
        $fingerprint,
        "-$seconds seconds"
    );

    if ( $recent_hash_id ) {
        # A recent entry exists, so return its id
        $result_id = $recent_hash_id;
    }
    else {

        # The SQLite database engine does not have support to create the "hash_id" by a
        # database engine trigger. "hash_id" is assumed to hold a unique hash. Uniqueness
        # cannot, however, be guaranteed. Same as with the other database engines.
        my $hash_id = substr(md5_hex(time().rand()), 0, 16);

        my $fields = 'hash_id, batch_id, priority, queue, params_deterministic_hash, params, domain, test_start_time, undelegated';
        $dbh->do(
            "INSERT INTO test_results ($fields) VALUES (?,?,?,?,?,?,?, datetime('now'),?)",
            undef,
            $hash_id,
            $batch_id,
            $priority,
            $queue_label,
            $fingerprint,
            $encoded_params,
            $test_params->{domain},
            $undelegated,
        );
        $result_id = $hash_id;
    }

    return $result_id; # Return test ID, either test previously run or just created.
}

sub test_progress {
    my ( $self, $test_id, $progress ) = @_;

    my $dbh = $self->dbh;
    if ( $progress ) {
        if ($progress == 1) {
            $dbh->do( "UPDATE test_results SET progress=?, test_start_time=datetime('now') WHERE hash_id=? AND progress <> 100", undef, $progress, $test_id );
        }
        elsif ($progress == 100) {
            $dbh->do( "UPDATE test_results SET progress=?, test_end_time=datetime('now') WHERE hash_id=? AND progress <> 100", undef, $progress, $test_id );
        }
        else {
            $dbh->do( "UPDATE test_results SET progress=? WHERE hash_id=? AND progress <> 100", undef, $progress, $test_id );
        }
    }

    my ( $result ) = $self->dbh->selectrow_array( "SELECT progress FROM test_results WHERE hash_id=?", undef, $test_id );

    return $result;
}

sub get_test_params {
    my ( $self, $test_id ) = @_;

    my ( $params_json ) = $self->dbh->selectrow_array( "SELECT params FROM test_results WHERE hash_id=?", undef, $test_id );

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

sub test_results {
    my ( $self, $test_id ) = @_;

    my $result;
    my ( $hrefs ) = $self->dbh->selectall_hashref( "SELECT id, hash_id, creation_time, params FROM test_results WHERE hash_id=?", 'hash_id', undef, $test_id );
    $result            = $hrefs->{$test_id};

    die Zonemaster::Backend::Error::ResourceNotFound->new( message => "Test not found", data => { test_id => $test_id } )
        unless defined $result;

    my @result_entries = $self->dbh->selectall_array( "SELECT level, module, testcase, tag, timestamp, args FROM result_entries WHERE hash_id=?", { Slice => {} }, $test_id );

    eval {
        $result->{params}  = decode_json( $result->{params} );

        @result_entries = map {
            {
                %$_,
                args => decode_json( $_->{args} ) ,
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

    my $undelegated = "";
    if ($p->{filter} eq "undelegated") {
        $undelegated = "AND undelegated = 1";
    } elsif ($p->{filter} eq "delegated") {
        $undelegated = "AND undelegated = 0";
    }

    my @results;
    my $query = "
        SELECT
            (SELECT count(*) FROM result_entries where result_entries.hash_id = test_results.hash_id AND level = 'CRITICAL') AS nb_critical,
            (SELECT count(*) FROM result_entries where result_entries.hash_id = test_results.hash_id AND level = 'ERROR') AS nb_error,
            (SELECT count(*) FROM result_entries where result_entries.hash_id = test_results.hash_id AND level = 'WARNING') AS nb_warning,
            id,
            hash_id,
            creation_time
        FROM test_results
        WHERE domain = " . $dbh->quote( $p->{frontend_params}->{domain} ) . " $undelegated
        ORDER BY id DESC
        LIMIT $p->{limit} OFFSET $p->{offset}";
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

        $dbh->{AutoCommit} = 0;
        eval {$dbh->do( "DROP INDEX IF EXISTS test_results__hash_id " );};
        eval {$dbh->do( "DROP INDEX IF EXISTS test_results__params_deterministic_hash " );};
        eval {$dbh->do( "DROP INDEX IF EXISTS test_results__batch_id_progress " );};
        eval {$dbh->do( "DROP INDEX IF EXISTS test_results__progress " );};
        eval {$dbh->do( "DROP INDEX IF EXISTS test_results__domain_undelegated " );};

        my $sth = $dbh->prepare( 'INSERT INTO test_results (hash_id, domain, batch_id, priority, queue, params_deterministic_hash, params, undelegated) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ' );
        foreach my $domain ( @{$params->{domains}} ) {
            $test_params->{domain} = $domain;

            my $fingerprint = $self->generate_fingerprint( $test_params );
            my $encoded_params = $self->encode_params( $test_params );
            my $undelegated = $self->undelegated ( $test_params );

            $sth->execute( substr(md5_hex(time().rand()), 0, 16), $test_params->{domain}, $batch_id, $priority, $queue_label, $fingerprint, $encoded_params, $undelegated );
        }
        $dbh->do( "CREATE INDEX test_results__hash_id ON test_results (hash_id, creation_time)" );
        $dbh->do( "CREATE INDEX test_results__params_deterministic_hash ON test_results (params_deterministic_hash)" );
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
    my ( $self, $queue_label, $test_run_timeout, $test_run_max_retries ) = @_;

    if ( $queue_label ) {
        my $sth = $self->dbh->prepare( "
            SELECT hash_id, results, nb_retries
            FROM test_results
            WHERE test_start_time < DATETIME('now', ?)
            AND nb_retries <= ?
            AND progress > 0
            AND progress < 100
            AND queue = ?" );
        $sth->execute(    #
            sprintf( "-%d seconds", $test_run_timeout ),
            $test_run_max_retries,
            $queue_label,
        );
        return $sth;
    }
    else {
        my $sth = $self->dbh->prepare( "
            SELECT hash_id, results, nb_retries
            FROM test_results
            WHERE test_start_time < DATETIME('now', ?)
            AND nb_retries <= ?
            AND progress > 0
            AND progress < 100" );
        $sth->execute(    #
            sprintf( "-%d seconds", $test_run_timeout ),
            $test_run_max_retries,
        );
        return $sth;
    }
}

sub schedule_for_retry {
    my ( $self, $hash_id ) = @_;

    $self->dbh->do("UPDATE test_results SET nb_retries = nb_retries + 1, progress = 0, test_start_time = DATETIME('now') WHERE hash_id=?", undef, $hash_id);
}

sub get_relative_start_time {
    my ( $self, $hash_id ) = @_;

    return $self->dbh->selectrow_array("SELECT (julianday('now') - julianday(test_start_time)) * 3600 * 24 FROM test_results WHERE hash_id=?", undef, $hash_id);
}

no Moose;
__PACKAGE__->meta()->make_immutable();

1;
