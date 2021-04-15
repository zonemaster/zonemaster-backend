use strict;
use warnings;
use utf8;

use Test::More tests => 2;
use Test::NoWarnings;
use Test::Exception;
use Log::Any::Test;    # Must come before use Log::Any
use Log::Any qw( $log );

subtest 'Everything but NoWarnings' => sub {

    use_ok( 'Zonemaster::Backend::Config' );

    lives_and {
        my $text = q{
            [DB]
            engine           = sqlite
            polling_interval = 1.5

            [MYSQL]
            host     = mysql-host
            user     = mysql_user
            password = mysql_password
            database = mysql_database

            [POSTGRESQL]
            host     = postgresql-host
            user     = postgresql_user
            password = postgresql_password
            database = postgresql_database

            [SQLITE]
            database_file = /var/db/zonemaster.sqlite

            [ZONEMASTER]
            max_zonemaster_execution_time            = 1200
            number_of_processes_for_frontend_testing = 30
            number_of_processes_for_batch_testing    = 40
            lock_on_queue                            = 1
            maximal_number_of_retries                = 2
            age_reuse_previous_test                  = 800
        };
        my $config = Zonemaster::Backend::Config->parse( $text );
        isa_ok $config, 'Zonemaster::Backend::Config', 'parse() return value';
        is $config->BackendDBType,                       'SQLite',                    'set: DB.engine';
        is $config->PollingInterval,                     1.5,                         'set: DB.polling_interval';
        is $config->MYSQL_host,                          'mysql-host',                'set: MYSQL.host';
        is $config->MYSQL_user,                          'mysql_user',                'set: MYSQL.user';
        is $config->MYSQL_password,                      'mysql_password',            'set: MYSQL.password';
        is $config->MYSQL_database,                      'mysql_database',            'set: MYSQL.database';
        is $config->POSTGRESQL_host,                     'postgresql-host',           'set: POSTGRESQL.host';
        is $config->POSTGRESQL_user,                     'postgresql_user',           'set: POSTGRESQL.user';
        is $config->POSTGRESQL_password,                 'postgresql_password',       'set: POSTGRESQL.password';
        is $config->POSTGRESQL_database,                 'postgresql_database',       'set: POSTGRESQL.database';
        is $config->SQLITE_database_file,                '/var/db/zonemaster.sqlite', 'set: SQLITE.database_file';
        is $config->MaxZonemasterExecutionTime,          1200,                        'set: ZONEMASTER.max_zonemaster_execution_time';
        is $config->maximal_number_of_retries,           2,                           'set: ZONEMASTER.maximal_number_of_retries';
        is $config->NumberOfProcessesForFrontendTesting, 30,                          'set: ZONEMASTER.number_of_processes_for_frontend_testing';
        is $config->NumberOfProcessesForBatchTesting,    40,                          'set: ZONEMASTER.number_of_processes_for_batch_testing';
        is $config->lock_on_queue,                       1,                           'set: ZONEMASTER.lock_on_queue';
        is $config->age_reuse_previous_test,             800,                         'set: ZONEMASTER.age_reuse_previous_test';
    };

    lives_and {
        my $text = q{
            [DB]
            engine = SQLite

            [SQLITE]
            database_file = /var/db/zonemaster.sqlite
        };
        my $config = Zonemaster::Backend::Config->parse( $text );
        cmp_ok abs( $config->PollingInterval - 0.5 ), '<', 0.000001, 'default: DB.polling_interval';
        is $config->MaxZonemasterExecutionTime,          600, 'default: ZONEMASTER.max_zonemaster_execution_time';
        is $config->maximal_number_of_retries,           0,   'default: ZONEMASTER.maximal_number_of_retries';
        is $config->NumberOfProcessesForFrontendTesting, 20,  'default: ZONEMASTER.number_of_processes_for_frontend_testing';
        is $config->NumberOfProcessesForBatchTesting,    20,  'default: ZONEMASTER.number_of_processes_for_batch_testing';
        is $config->lock_on_queue,                       0,   'default: ZONEMASTER.lock_on_queue';
        is $config->age_reuse_previous_test,             600, 'default: ZONEMASTER.age_reuse_previous_test';
    };

    lives_and {
        my $text = q{
            [DB]
            engine        = MySQL
            database_host = db-host
            user          = db_user
            password      = db_password
            database_name = db_database
        };
        my $config = Zonemaster::Backend::Config->parse( $text );
        $log->contains_ok( qr/deprecated.*DB\.database_host/, 'deprecated: DB.database_host' );
        $log->contains_ok( qr/deprecated.*DB\.user/,          'deprecated: DB.user' );
        $log->contains_ok( qr/deprecated.*DB\.password/,      'deprecated: DB.password' );
        $log->contains_ok( qr/deprecated.*DB\.database_name/, 'deprecated: DB.database_name' );
        is $config->MYSQL_host,     'db-host',     'fallback: MYSQL.host';
        is $config->MYSQL_user,     'db_user',     'fallback: MYSQL.user';
        is $config->MYSQL_password, 'db_password', 'fallback: MYSQL.password';
        is $config->MYSQL_database, 'db_database', 'fallback: MYSQL.database';
    };

    lives_and {
        my $text = q{
            [DB]
            engine        = PostgreSQL
            database_host = db-host
            user          = db_user
            password      = db_password
            database_name = db_database
        };
        my $config = Zonemaster::Backend::Config->parse( $text );
        $log->contains_ok( qr/deprecated.*DB\.database_host/, 'deprecated: DB.database_host' );
        $log->contains_ok( qr/deprecated.*DB\.user/,          'deprecated: DB.user' );
        $log->contains_ok( qr/deprecated.*DB\.password/,      'deprecated: DB.password' );
        $log->contains_ok( qr/deprecated.*DB\.database_name/, 'deprecated: DB.database_name' );
        is $config->POSTGRESQL_host,     'db-host',     'fallback: POSTGRESQL.host';
        is $config->POSTGRESQL_user,     'db_user',     'fallback: POSTGRESQL.user';
        is $config->POSTGRESQL_password, 'db_password', 'fallback: POSTGRESQL.password';
        is $config->POSTGRESQL_database, 'db_database', 'fallback: POSTGRESQL.database';
    };

    lives_and {
        my $text = q{
            [DB]
            engine        = SQLite
            database_host = db-host
            user          = db_user
            password      = db_password
            database_name = /var/db/zonemaster.sqlite
        };
        my $config = Zonemaster::Backend::Config->parse( $text );
        $log->contains_ok( qr/deprecated.*DB\.database_host/, 'deprecated: DB.database_host' );
        $log->contains_ok( qr/deprecated.*DB\.user/,          'deprecated: DB.user' );
        $log->contains_ok( qr/deprecated.*DB\.password/,      'deprecated: DB.password' );
        $log->contains_ok( qr/deprecated.*DB\.database_name/, 'deprecated: DB.database_name' );
        is $config->SQLITE_database_file, '/var/db/zonemaster.sqlite', 'fallback: SQLITE.database_file';
    };

    throws_ok {
        my $text = '{"this":"is","not":"a","valid":"ini","file":"!"}';
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/Failed to parse config/, 'die: Invalid INI format';

    throws_ok {
        my $text = q{
            [DB]
            engine = Excel
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/DB\.engine.*Excel/, 'die: Invalid DB.engine value';

    throws_ok {
        my $text = q{
            [DB]
            engine = SQLite

            [SQLITE]
            database_file = /var/db/zonemaster.sqlite

            [LANGUAGE]
            locale = English
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/LANGUAGE\.locale.*English/, 'die: Invalid locale_tag in LANGUAGE.locale';

    throws_ok {
        my $text = q{
            [DB]
            engine = SQLite

            [SQLITE]
            database_file = /var/db/zonemaster.sqlite

            [LANGUAGE]
            locale = en_US en_US
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/LANGUAGE\.locale.*en_US/, 'die: Repeated locale_tag in LANGUAGE.locale';
};
