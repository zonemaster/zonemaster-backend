use strict;
use warnings;

use JSON::PP;
use Try::Tiny;

use Zonemaster::Backend::Config;

my $config = Zonemaster::Backend::Config->load_config();

my %patch = (
    mysql       => \&patch_db_mysql,
    postgresql  => \&patch_db_postgresql,
    sqlite      => \&patch_db_sqlite,
);

my $db_engine = $config->DB_engine;
print "Configured database engine: $db_engine\n";

if ( $db_engine =~ /^(MySQL|PostgreSQL|SQLite)$/ ) {
    print( "Starting database migration\n" );
    $patch{ lc $db_engine }();
    print( "\nMigration done\n" );
}
else {
    die "Unknown database engine configured: $db_engine\n";
}

sub _update_data_result_entries {
    my ( $dbh ) = @_;

    my $json = JSON::PP->new->allow_blessed->convert_blessed->canonical;

    # update only jobs with results
    my ( $row_total ) = $dbh->selectrow_array( 'SELECT count(*) FROM test_results WHERE results IS NOT NULL' );
    print "Will update $row_total rows\n";

    my %levels = Zonemaster::Engine::Logger::Entry->levels();

    # depending on the resources available to select all data in database
    # update $row_count to your needs
    my $row_count = 50000;
    my $row_done = 0;
    while ( $row_done < $row_total ) {
        print "Progress update: $row_done / $row_total\n";
        my $row_updated = 0;
        my $sth1 = $dbh->prepare( 'SELECT hash_id, results FROM test_results WHERE results IS NOT NULL ORDER BY id ASC LIMIT ?,?' );
        $sth1->execute( $row_done, $row_count );
        while ( my $row = $sth1->fetchrow_arrayref ) {
            my ( $hash_id, $results ) = @$row;

            next unless $results;

            my @records;
            my $entries = $json->decode( $results );

            foreach my $m ( @$entries ) {
                my $r = [
                    $hash_id,
                    $levels{ $m->{level} },
                    $m->{module},
                    $m->{testcase} // '',
                    $m->{tag},
                    $m->{timestamp},
                    $json->encode( $m->{args} // {} ),
                ];

                push @records, $r;
            }

            my $query_values = join ", ", ("(?, ?, ?, ?, ?, ?, ?)") x @records;
            my $query = "INSERT INTO result_entries (hash_id, level, module, testcase, tag, timestamp, args) VALUES $query_values";
            my $sth = $dbh->prepare( $query );
            $sth = $sth->execute( map { @$_ } @records );

            $row_updated += $dbh->do( "UPDATE test_results SET results = NULL WHERE hash_id = ?", undef, $hash_id );
        }

        # increase by min(row_updated, row_count)
        $row_done += ( $row_updated < $row_count ) ? $row_updated : $row_count;
    }
    print "Progress update: $row_done / $row_total\n";
}

sub _update_data_nomalize_domains {
    my ( $db ) = @_;

    my ( $row_total ) = $db->dbh->selectrow_array( 'SELECT count(*) FROM test_results' );
    print "Will update $row_total rows\n";


    my $sth1 = $db->dbh->prepare( 'SELECT hash_id, params FROM test_results' );
    $sth1->execute;

    my $row_done = 0;
    my $progress = 0;

    while ( my $row = $sth1->fetchrow_hashref ) {
        my $hash_id = $row->{hash_id};
        eval {
            my $raw_params = decode_json($row->{params});
            my $domain = $raw_params->{domain};

            # This has never been cleaned
            delete $raw_params->{user_ip};

            my $params = $db->encode_params( $raw_params );
            my $fingerprint = $db->generate_fingerprint( $raw_params );

            $domain = Zonemaster::Backend::DB::_normalize_domain( $domain );

            $db->dbh->do('UPDATE test_results SET domain = ?, params = ?, fingerprint = ? where hash_id = ?', undef, $domain, $params, $fingerprint, $hash_id);
        };
        if ($@) {
            warn "Caught error while updating record with hash id $hash_id, ignoring: $@\n";
        }
        $row_done += 1;
        my $new_progress = int(($row_done / $row_total) * 100);
        if ( $new_progress != $progress ) {
            $progress = $new_progress;
            print("$progress%\n");
        }
    }
}

sub patch_db_mysql {
    use Zonemaster::Backend::DB::MySQL;

    my $db = Zonemaster::Backend::DB::MySQL->from_config( $config );
    my $dbh = $db->dbh;

    $dbh->{AutoCommit} = 0;

    try {
        $db->create_schema();

        print( "\n-> (1/2) Populating new result_entries table\n" );
        _update_data_result_entries( $dbh );

        print( "\n-> (2/2) Normalizing domain names\n" );
        _update_data_nomalize_domains( $db );

        $dbh->commit();
    } catch {
        print( "Could not upgrade database:  " . $_ );

        $dbh->rollback();
    };
}

sub patch_db_postgresql {
    use Zonemaster::Backend::DB::PostgreSQL;

    my $db = Zonemaster::Backend::DB::PostgreSQL->from_config( $config );
    my $dbh = $db->dbh;

    $dbh->{AutoCommit} = 0;

    try {
        $db->create_schema();

        print( "\n-> (1/2) Populating new result_entries table\n" );

        $dbh->do(q[
            INSERT INTO result_entries (
                hash_id, args, module, level, tag, timestamp, testcase
            )
            (
                select
                    hash_id,
                    (CASE WHEN res->'args' IS NULL THEN '{}' ELSE res->'args' END) AS args,
                    res->>'module' AS module,
                    (SELECT value FROM log_level WHERE level = (res->>'level')) AS level,
                    res->>'tag' AS tag,
                    (res->>'timestamp')::real AS timestamp,
                    (CASE WHEN res->>'testcase' IS NULL THEN '' ELSE res->>'testcase' END) AS testcase
                FROM
                (
                    SELECT
                        json_array_elements(results) AS res,
                        hash_id
                    FROM test_results
                ) AS s1
            )
        ]);

        $dbh->do(
            'UPDATE test_results SET results = NULL WHERE results IS NOT NULL'
        );


        print( "\n-> (2/2) Normalizing domain names\n" );
        _update_data_nomalize_domains( $db );

        $dbh->commit();
    } catch {
        print( "Could not upgrade database:  " . $_ );

        $dbh->rollback();
    };
}

sub patch_db_sqlite {
    use Zonemaster::Backend::DB::SQLite;

    my $db = Zonemaster::Backend::DB::SQLite->from_config( $config );
    my $dbh = $db->dbh;

    $dbh->{AutoCommit} = 0;

    try {
        $db->create_schema();

        print( "\n-> (1/2) Populating new result_entries table\n" );
        _update_data_result_entries( $dbh );

        print( "\n-> (2/2) Normalizing domain names\n" );
        _update_data_nomalize_domains( $db );

        $dbh->commit();
    } catch {
        print( "Error while upgrading database:  " . $_ );

        $dbh->rollback();
    };
}
