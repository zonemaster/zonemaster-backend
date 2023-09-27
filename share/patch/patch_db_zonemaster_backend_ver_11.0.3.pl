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
print "engine: $db_engine\n";

if ( $db_engine =~ /^(MySQL|PostgreSQL|SQLite)$/ ) {
    $patch{ lc $db_engine }();
}
else {
    die "Unknown database engine configured: $db_engine\n";
}

sub _update_data {
    my ( $dbh ) = @_;

    my $json = JSON::PP->new->allow_blessed->convert_blessed->canonical;

    my ( $row_total ) = $dbh->selectrow_array( 'SELECT count(*) FROM test_results' );
    print "count: $row_total\n";

    # depending on the resources available to select all data in database
    # update $row_count to your needs
    my $row_count = 50000;
    my $row_done = 0;
    while ( $row_done < $row_total ) {
        print "row_done/row_total: $row_done / $row_total\n";
        my $sth1 = $dbh->prepare( 'SELECT hash_id, results FROM test_results ORDER BY id ASC LIMIT ?,?' );
        $sth1->execute( $row_done, $row_count );
        while ( my $row = $sth1->fetchrow_arrayref ) {
            my ( $hash_id, $results ) = @$row;

            next unless $results;

            my @records;
            my $entries = $json->decode( $results );

            foreach my $m ( @$entries ) {
                my $r = [
                    $hash_id,
                    $m->{level},
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

            $dbh->do( "UPDATE test_results SET results = NULL WHERE hash_id = ?", undef, $hash_id );
        }

        $row_done += $row_count;
    }
}

sub patch_db_mysql {
    use Zonemaster::Backend::DB::MySQL;

    my $db = Zonemaster::Backend::DB::MySQL->from_config( $config );
    my $dbh = $db->dbh;

    $dbh->{AutoCommit} = 0;

    try {
        $db->create_schema();

        _update_data( $dbh );

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

        $dbh->do(q[
            INSERT INTO result_entries (
                hash_id, args, module, level, tag, timestamp, testcase
            )
            (
                select
                    hash_id,
                    (CASE WHEN res->'args' IS NULL THEN '{}' ELSE res->'args' END) AS args,
                    res->>'module' AS module,
                    (res->>'level') AS level,
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

        _update_data( $dbh );

        $dbh->commit();
    } catch {
        print( "Error while upgrading database:  " . $_ );

        $dbh->rollback();
    };
}
