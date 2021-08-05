use strict;
use warnings;

use DBI qw(:utils);

use Zonemaster::Backend::Config;
use Zonemaster::Backend::DB::PostgreSQL;

my $config = Zonemaster::Backend::Config->load_config();
if ( $config->DB_engine ne 'PostgreSQL' ) {
    die "The configuration file does not contain the PostgreSQL backend";
}
my $dbh = Zonemaster::Backend::DB::PostgreSQL->from_config( $config )->dbh;

sub patch_db {

    ####################################################################
    # TEST RESULTS
    ####################################################################
    eval {
        $dbh->do( 'ALTER TABLE test_results ADD COLUMN undelegated integer NOT NULL DEFAULT 0' );
    };
    if ($@) {
        print "Error while changing DB schema:  " . $@;
    }

    $dbh->do( qq[
update test_results set undelegated = test_results_undelegated.undelegated_bool::int
from (
    select
        test_results.id,
        (
            case when ds_filled.ds_filled is null then false else ds_filled.ds_filled end
            or
            case when ns_filled.ns_filled is null then false else ns_filled.ns_filled end
        ) as undelegated_bool
    from test_results
    left join (
        select
            count(*) > 0 as ds_filled,
            id
        from (
            select
                jd.value,
                id
            from
            (
                select json_array_elements(params->'ds_info') as ja, id
                from test_results
            )  as s1,
            json_each_text(ja) as jd
        ) as s2
        where value is not null and value::text != ''::text
        group by id
    ) as ds_filled on ds_filled.id = test_results.id
    left join (
            select
            count(*) > 0 as ns_filled,
            id
        from (
            select
                jd.value,
                id
            from
            (
                select json_array_elements(params->'nameservers') as ja, id
                from test_results
            )  as s1,
            json_each_text(ja) as jd
        ) as s2
        where value is not null and value::text != ''::text
        group by id
    ) as ns_filled on ns_filled.id = test_results.id
) as test_results_undelegated where test_results.id = test_results_undelegated.id;
    ] );
}

patch_db();
