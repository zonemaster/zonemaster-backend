use strict;
use warnings;
use utf8;
use Data::Dumper;
use Encode;
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
    my @arefs = $dbh->selectall_array('SELECT id, params from test_results', undef);
    foreach my $row (@arefs) {
        my $id = @$row[0];
        my $raw_params = decode_json(@$row[1]);
        my $ds_info_values = scalar( map { grep (!/^$/, values( %$_ ) ) } @{$raw_params->{ds_info}});
        my $nameservers_values = scalar( map { grep (!/^$/, values( %$_ ) ) } @{$raw_params->{nameservers}});
        my $undelegated = $ds_info_values > 0 || $nameservers_values > 0 || 0;

        $dbh->do('UPDATE test_results SET undelegated = ? where id = ?', undef, $undelegated, $id);
    }
}

patch_db();
