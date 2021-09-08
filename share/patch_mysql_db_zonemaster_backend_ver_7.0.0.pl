use strict;
use warnings;
use JSON::PP;

use DBI qw(:utils);

use Zonemaster::Backend::Config;
use Zonemaster::Backend::DB::MySQL;

my $config = Zonemaster::Backend::Config->load_config();
if ( $config->DB_engine ne 'MySQL' ) {
    die "The configuration file does not contain the MySQL backend";
}
my $db = Zonemaster::Backend::DB::MySQL->from_config( $config );
my $dbh = $db->dbh;


sub patch_db {
    my $sth1 = $dbh->prepare('SELECT id, params from test_results', undef);
    $sth1->execute;
    while ( my $row = $sth1->fetchrow_hashref ) {
        my $id = $row->{id};
        my $raw_params = decode_json($row->{params});
        my $ds_info_values = scalar grep !/^$/, map { values %$_ } @{$raw_params->{ds_info}};
        my $nameservers_values = scalar grep !/^$/, map { values %$_ } @{$raw_params->{nameservers}};
        my $undelegated = $ds_info_values > 0 || $nameservers_values > 0 || 0;

        $dbh->do('UPDATE test_results SET undelegated = ? where id = ?', undef, $undelegated, $id);
    }
}

patch_db();
