use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::NoWarnings qw( had_no_warnings );

use File::ShareDir qw( dist_file );
use File::Temp     qw( tempdir );

my $t_path;

BEGIN {
    use File::Spec::Functions qw( rel2abs );
    use File::Basename        qw( dirname );
    $t_path = dirname( rel2abs( $0 ) );
}
use lib $t_path;

use TestUtil;

use Zonemaster::Backend::Config;
use Zonemaster::Backend::RPCAPI;
use Zonemaster::Backend::TestAgent;

my $db_backend = TestUtil::db_backend();

my $tempdir = tempdir( CLEANUP => 1 );
my $config  = Zonemaster::Backend::Config->parse( <<EOF );
[DB]
engine = $db_backend

[MYSQL]
host     = localhost
user     = zonemaster_test
password = zonemaster
database = zonemaster_test

[POSTGRESQL]
host     = localhost
user     = zonemaster_test
password = zonemaster
database = zonemaster_test

[SQLITE]
database_file = $tempdir/zonemaster.sqlite

[ZONEMASTER]
age_reuse_previous_test = 10
EOF
my $profiles = Zonemaster::Backend::Config->load_profiles(    #
    $config->PUBLIC_PROFILES,
    $config->PRIVATE_PROFILES,
);

my $dbclass = Zonemaster::Backend::DB->get_db_class( $db_backend );
my $db      = $dbclass->from_config( $config );

subtest 'newly created database' => sub {
    $db->drop_tables();
    $db->create_schema();

    my $schema_version = $db->get_schema_version;
    like $schema_version, qr{^[1-9][0-9]*$}, 'should report schema version as an integer';

    lives_ok { $db->assert_compatible_schema } 'should pass compatibility assertion';
    lives_ok { Zonemaster::Backend::TestAgent->new( { config => $config } ) } 'should be accepted by TestAgent constructor';
    lives_ok { Zonemaster::Backend::RPCAPI->new( config => $config, db => $config->new_DB, profiles => $profiles ) } 'should be accepted by RPCAPI constructor';
};

subtest 'database with future schema version' => sub {
    $db->drop_tables();
    $db->create_schema();
    $db->dbh->do( 'UPDATE schema_version SET version = ?', {}, $Zonemaster::Backend::DB::REQUIRED_SCHEMA_VERSION + 1 );

    my $schema_version = $db->get_schema_version;
    like $schema_version, qr{^[1-9][0-9]*$}, 'should report schema version as an integer';

    dies_ok { $db->assert_compatible_schema } 'should fail compatibility assertion';
    dies_ok { Zonemaster::Backend::RPCAPI->new( config => $config, db => $config->new_DB, profiles => $profiles ) } 'should be rejected by RPCAPI constructor';
    dies_ok { Zonemaster::Backend::TestAgent->new( { config => $config } ) } 'should be rejected by TestAgent constructor';
};

subtest 'database per Backend 11.2.0' => sub {
    $db->drop_tables();
    $db->create_schema();
    $db->dbh->do( 'DROP TABLE schema_version' );

    my $schema_version = $db->get_schema_version;
    is $schema_version, 0, 'should be inferred as schema version 0';

    dies_ok { $db->assert_compatible_schema } 'should fail compatibility assertion';
    dies_ok { Zonemaster::Backend::RPCAPI->new( config => $config, db => $config->new_DB, profiles => $profiles ) } 'should be rejected by RPCAPI constructor';
    dies_ok { Zonemaster::Backend::TestAgent->new( { config => $config } ) } 'should be rejected by TestAgent constructor';
};

subtest 'database with unrecognized schema version table structure' => sub {
    $db->drop_tables();
    $db->create_schema();
    $db->dbh->do( "DROP TABLE schema_version" );
    $db->dbh->do( "CREATE TABLE schema_version (foobar INTEGER)" );

    dies_ok { $db->get_schema_version; } 'should die instead of reporting a schema version';
    dies_ok { $db->assert_compatible_schema } 'should fail compatibility assertion';
    dies_ok { Zonemaster::Backend::RPCAPI->new( config => $config, db => $config->new_DB, profiles => $profiles ) } 'should be rejected by RPCAPI constructor';
    dies_ok { Zonemaster::Backend::TestAgent->new( { config => $config } ) } 'should be rejected by TestAgent constructor';
};

subtest 'database with empty schema version table' => sub {
    $db->drop_tables();
    $db->create_schema();
    $db->dbh->do( "DELETE FROM schema_version" );

    dies_ok { $db->get_schema_version; } 'should die instead of reporting a schema version';
    dies_ok { $db->assert_compatible_schema } 'should fail compatibility assertion';
    dies_ok { Zonemaster::Backend::RPCAPI->new( config => $config, db => $config->new_DB, profiles => $profiles ) } 'should be rejected by RPCAPI constructor';
    dies_ok { Zonemaster::Backend::TestAgent->new( { config => $config } ) } 'should be rejected by TestAgent constructor';
};

had_no_warnings;
done_testing;
