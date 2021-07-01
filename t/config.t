use strict;
use warnings;
use utf8;

use Test::More tests => 2;
use Test::NoWarnings;
use Test::Differences;
use Test::Exception;
use Log::Any::Test;    # Must come before use Log::Any

use File::Basename qw( dirname );
use File::Slurp qw( read_file );
use File::Spec::Functions qw( catfile );
use Log::Any qw( $log );

subtest 'Everything but NoWarnings' => sub {

    use_ok( 'Zonemaster::Backend::Config' );

    subtest 'Set values' => sub {
        my $text = q{
            [DB]
            engine           = sqlite
            polling_interval = 1.5

            [MYSQL]
            host     = mysql-host
            port     = 3456
            user     = mysql_user
            password = mysql_password
            database = mysql_database

            [POSTGRESQL]
            host     = postgresql-host
            port     = 6543
            user     = postgresql_user
            password = postgresql_password
            database = postgresql_database

            [SQLITE]
            database_file = /var/db/zonemaster.sqlite

            [LANGUAGE]
            locale = sv_FI

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
        is $config->DB_engine,            'SQLite',                    'set: DB.engine';
        is $config->DB_polling_interval,  1.5,                         'set: DB.polling_interval';
        is $config->MYSQL_host,           'mysql-host',                'set: MYSQL.host';
        is $config->MYSQL_port,           3456,                        'set: MYSQL.port';
        is $config->MYSQL_user,           'mysql_user',                'set: MYSQL.user';
        is $config->MYSQL_password,       'mysql_password',            'set: MYSQL.password';
        is $config->MYSQL_database,       'mysql_database',            'set: MYSQL.database';
        is $config->POSTGRESQL_host,      'postgresql-host',           'set: POSTGRESQL.host';
        is $config->POSTGRESQL_port,      6543,                        'set: POSTGRESQL.port';
        is $config->POSTGRESQL_user,      'postgresql_user',           'set: POSTGRESQL.user';
        is $config->POSTGRESQL_password,  'postgresql_password',       'set: POSTGRESQL.password';
        is $config->POSTGRESQL_database,  'postgresql_database',       'set: POSTGRESQL.database';
        is $config->SQLITE_database_file, '/var/db/zonemaster.sqlite', 'set: SQLITE.database_file';
        eq_or_diff { $config->LANGUAGE_locale }, { sv => { sv_FI => 1 } }, 'set: LANGUAGE.locale';
        is $config->ZONEMASTER_max_zonemaster_execution_time,            1200, 'set: ZONEMASTER.max_zonemaster_execution_time';
        is $config->ZONEMASTER_maximal_number_of_retries,                2,    'set: ZONEMASTER.maximal_number_of_retries';
        is $config->ZONEMASTER_number_of_processes_for_frontend_testing, 30,   'set: ZONEMASTER.number_of_processes_for_frontend_testing';
        is $config->ZONEMASTER_number_of_processes_for_batch_testing,    40,   'set: ZONEMASTER.number_of_processes_for_batch_testing';
        is $config->ZONEMASTER_lock_on_queue,                            1,    'set: ZONEMASTER.lock_on_queue';
        is $config->ZONEMASTER_age_reuse_previous_test,                  800,  'set: ZONEMASTER.age_reuse_previous_test';
    };

    subtest 'Default values' => sub {
        my $text = q{
            [DB]
            engine = SQLite

            [SQLITE]
            database_file = /var/db/zonemaster.sqlite
        };
        my $config = Zonemaster::Backend::Config->parse( $text );
        cmp_ok abs( $config->DB_polling_interval - 0.5 ), '<', 0.000001, 'default: DB.polling_interval';
        is $config->MYSQL_port,      3306, 'default: MYSQL.port';
        is $config->POSTGRESQL_port, 5432, 'default: POSTGRESQL.port';
        eq_or_diff { $config->LANGUAGE_locale }, { en => { en_US => 1 } }, 'default: LANGUAGE.locale';
        is $config->ZONEMASTER_max_zonemaster_execution_time,            600, 'default: ZONEMASTER.max_zonemaster_execution_time';
        is $config->ZONEMASTER_maximal_number_of_retries,                0,   'default: ZONEMASTER.maximal_number_of_retries';
        is $config->ZONEMASTER_number_of_processes_for_frontend_testing, 20,  'default: ZONEMASTER.number_of_processes_for_frontend_testing';
        is $config->ZONEMASTER_number_of_processes_for_batch_testing,    20,  'default: ZONEMASTER.number_of_processes_for_batch_testing';
        is $config->ZONEMASTER_lock_on_queue,                            0,   'default: ZONEMASTER.lock_on_queue';
        is $config->ZONEMASTER_age_reuse_previous_test,                  600, 'default: ZONEMASTER.age_reuse_previous_test';
    };

    subtest 'Deprecated values and fallbacks when DB.engine = MySQL' => sub {
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

    subtest 'Deprecated values and fallbacks when DB.engine = PostgreSQL' => sub {
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

    subtest 'Deprecated values and fallbacks when DB.engine = SQLite' => sub {
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

    subtest 'Deprecated values and fallbacks that are unconditional' => sub {
        my $text = q{
            [DB]
            engine = SQLite
            [SQLITE]
            database_file = /var/db/zonemaster.sqlite
            [LANGUAGE]
            locale =
            [ZONEMASTER]
            number_of_professes_for_frontend_testing = 21
            number_of_professes_for_batch_testing    = 22
        };
        my $config = Zonemaster::Backend::Config->parse( $text );
        $log->contains_ok( qr/deprecated.*ZONEMASTER\.number_of_professes_for_frontend_testing/, 'deprecated: ZONEMASTER.number_of_professes_for_frontend_testing' );
        $log->contains_ok( qr/deprecated.*ZONEMASTER\.number_of_professes_for_batch_testing/,    'deprecated: ZONEMASTER.number_of_professes_for_batch_testing' );
        $log->contains_ok( qr/deprecated.*LANGUAGE\.locale/,                                     'deprecated empty LANGUAGE.locale' );
        is $config->ZONEMASTER_number_of_processes_for_frontend_testing, '21', 'fallback: ZONEMASTER.number_of_processes_for_frontend_testing';
        is $config->ZONEMASTER_number_of_processes_for_batch_testing,    '22', 'fallback: ZONEMASTER.number_of_processes_for_batch_testing';
    };

    subtest 'Warnings' => sub {
        my $text = q{
            [DB]
            engine = MySQL

            [MYSQL]
            host     = localhost
            port     = 3333
            user     = mysql_user
            password = mysql_password
            database = mysql_database
        };
        my $config = Zonemaster::Backend::Config->parse( $text );
        $log->contains_ok( qr/MYSQL\.port.*MYSQL\.host/, 'warning: MYSQL.host is "localhost" and MYSQL.port defined' );
        is $config->MYSQL_host, 'localhost', 'set: MYSQL.host';
        is $config->MYSQL_port, 3333,        'set: MYSQL.port';
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

            [SQLITE]
            databse_file = /var/db/zonemaster.sqlite

            [ZNMEOTAESR]
            lock_on_queue = 1
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{section.*ZNMEOTAESR}, 'die: Invalid section name';

    throws_ok {
        my $text = q{
            [DB]
            engine = SQLite
            pnlilog_iatnvrel = 0.5

            [SQLITE]
            database_file = /var/db/zonemaster.sqlite
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{property.*pnlilog_iatnvrel}, 'die: Invalid property name';

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
            polling_interval = hourly

            [SQLITE]
            databse_file = /var/db/zonemaster.sqlite
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{DB\.polling_interval.*hourly}, 'die: Invalid DB.polling_interval value';

    throws_ok {
        my $text = q{
            [DB]
            engine = MySQL

            [MYSQL]
            host = 192.0.2.1:3306
            user = zonemaster_user
            password = zonemaster_password
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{MYSQL\.host.*192.0.2.1:3306}, 'die: Invalid MYSQL.host value';

    throws_ok {
        my $text = q{
            [DB]
            engine = MySQL

            [MYSQL]
            host = zonemaster-host
            user = Robert'); DROP TABLE Students;--
            password = zonemaster_password
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{MYSQL\.user.*Robert'\); DROP TABLE Students;--}, 'die: Invalid MYSQL.user value';

    throws_ok {
        my $text = q{
            [DB]
            engine = MySQL

            [MYSQL]
            host = zonemaster-host
            user = zonemaster
            password = (╯°□°)╯︵ ┻━┻
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{MYSQL\.password.*\(╯°□°\)╯︵ ┻━┻}, 'die: Invalid MYSQL.password value';

    throws_ok {
        my $text = q{
            [DB]
            engine = MySQL

            [MYSQL]
            host = zonemaster-host
            user = zonemaster_user
            password = zonemaster_password
            database = |)/-\'|'/-\|3/-\$[-
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{MYSQL\.database.*|\)/-\'|'/-\\|3/-\\$[-}, 'die: Invalid MYSQL.database value';

    throws_ok {
        my $text = q{
            [DB]
            engine = PostgreSQL

            [POSTGRESQL]
            host = 192.0.2.1:5432
            user = zonemaster_user
            password = zonemaster_password
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{POSTGRESQL\.host.*192.0.2.1:5432}, 'die: Invalid POSTGRESQL.host value';

    throws_ok {
        my $text = q{
            [DB]
            engine = PostgreSQL

            [POSTGRESQL]
            host = zonemaster-host
            user = Robert'); DROP TABLE Students;--
            password = zonemaster_password
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{POSTGRESQL\.user.*Robert'\); DROP TABLE Students;--}, 'die: Invalid POSTGRESQL.user value';

    throws_ok {
        my $text = q{
            [DB]
            engine = PostgreSQL

            [POSTGRESQL]
            host = zonemaster-host
            user = zonemaster
            password = (╯°□°)╯︵ ┻━┻
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{POSTGRESQL\.password.*\(╯°□°\)╯︵ ┻━┻}, 'die: Invalid POSTGRESQL.password value';

    throws_ok {
        my $text = q{
            [DB]
            engine = PostgreSQL

            [POSTGRESQL]
            host = zonemaster-host
            user = zonemaster_user
            password = zonemaster_password
            database = |)/-\'|'/-\|3/-\$[-
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{POSTGRESQL\.database.*|\)/-\'|'/-\\|3/-\\$[-}, 'die: Invalid POSTGRESQL.database value';

    throws_ok {
        my $text = q{
            [DB]
            engine = SQLite

            [SQLITE]
            database_file = ./relative/path/to/zonemaster.sqlite
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{SQLITE\.database_file.*\./relative/path/to/zonemaster.sqlite}, 'die: Invalid SQLITE.database_file value';

    throws_ok {
        my $text = q{
            [DB]
            engine = SQLite

            [ZONEMASTER]
            max_zonemaster_execution_time = 0
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{ZONEMASTER\.max_zonemaster_execution_time.*0}, 'die: Invalid ZONEMASTER.max_zonemaster_execution_time value';

    throws_ok {
        my $text = q{
            [DB]
            engine = SQLite

            [ZONEMASTER]
            maximal_number_of_retries = -1
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{ZONEMASTER\.maximal_number_of_retries.*-1}, 'die: Invalid ZONEMASTER.maximal_number_of_retries value';

    throws_ok {
        my $text = q{
            [DB]
            engine = SQLite

            [ZONEMASTER]
            lock_on_queue = -1
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{ZONEMASTER\.lock_on_queue.*-1}, 'die: Invalid ZONEMASTER.lock_on_queue value';

    throws_ok {
        my $text = q{
            [DB]
            engine = SQLite

            [ZONEMASTER]
            number_of_processes_for_frontend_testing = 0
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{ZONEMASTER\.number_of_processes_for_frontend_testing.*0}, 'die: Invalid ZONEMASTER.number_of_processes_for_frontend_testing value';

    throws_ok {
        my $text = q{
            [DB]
            engine = SQLite

            [ZONEMASTER]
            number_of_processes_for_batch_testing = 100000
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{ZONEMASTER\.number_of_processes_for_batch_testing.*100000}, 'die: Invalid ZONEMASTER.number_of_processes_for_batch_testing value';

    throws_ok {
        my $text = q{
            [DB]
            engine = SQLite

            [ZONEMASTER]
            age_reuse_previous_test = 0
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr{ZONEMASTER\.age_reuse_previous_test.*0}, 'die: Invalid ZONEMASTER.age_reuse_previous_test value';

    throws_ok {
        my $text = q{
            [DB]
            engine = MySQL

            [MYSQL]
            user = zonemaster_user
            password = zonemaster_password
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/MYSQL\.host/, 'die: Missing MYSQL.host value';

    throws_ok {
        my $text = q{
            [DB]
            engine = MySQL

            [MYSQL]
            host = zonemaster-host
            password = zonemaster_password
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/MYSQL\.user/, 'die: Missing MYSQL.user value';

    throws_ok {
        my $text = q{
            [DB]
            engine = MySQL

            [MYSQL]
            host = zonemaster-host
            user = zonemaster_user
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/MYSQL\.password/, 'die: Missing MYSQL.password value';

    throws_ok {
        my $text = q{
            [DB]
            engine = MySQL

            [MYSQL]
            host = zonemaster-host
            user = zonemaster_user
            password = zonemaster_password
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/MYSQL\.database/, 'die: Missing MYSQL.database value';

    throws_ok {
        my $text = q{
            [DB]
            engine = PostgreSQL

            [POSTGRESQL]
            user = zonemaster_user
            password = zonemaster_password
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/POSTGRESQL\.host/, 'die: Missing POSTGRESQL.host value';

    throws_ok {
        my $text = q{
            [DB]
            engine = PostgreSQL

            [POSTGRESQL]
            host = zonemaster-host
            password = zonemaster_password
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/POSTGRESQL\.user/, 'die: Missing POSTGRESQL.user value';

    throws_ok {
        my $text = q{
            [DB]
            engine = PostgreSQL

            [POSTGRESQL]
            host = zonemaster-host
            user = zonemaster_user
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/POSTGRESQL\.password/, 'die: Missing POSTGRESQL.password value';

    throws_ok {
        my $text = q{
            [DB]
            engine = PostgreSQL

            [POSTGRESQL]
            host = zonemaster-host
            user = zonemaster_user
            password = zonemaster_password
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/POSTGRESQL\.database/, 'die: Missing POSTGRESQL.database value';

    throws_ok {
        my $text = q{
            [DB]
            engine = MySQL

            [MYSQL]
            user = zonemaster_user
            password = zonemaster_password
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/MYSQL\.host/, 'die: Missing MYSQL.host value';

    throws_ok {
        my $text = q{
            [DB]
            engine = MySQL

            [MYSQL]
            host = zonemaster-host
            password = zonemaster_password
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/MYSQL\.user/, 'die: Missing MYSQL.user value';

    throws_ok {
        my $text = q{
            [DB]
            engine = MySQL

            [MYSQL]
            host = zonemaster-host
            user = zonemaster_user
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/MYSQL\.password/, 'die: Missing MYSQL.password value';

    throws_ok {
        my $text = q{
            [DB]
            engine = MySQL

            [MYSQL]
            host = zonemaster-host
            user = zonemaster_user
            password = zonemaster_password
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/MYSQL\.database/, 'die: Missing MYSQL.database value';

    throws_ok {
        my $text = q{
            [DB]
            engine = PostgreSQL

            [POSTGRESQL]
            user = zonemaster_user
            password = zonemaster_password
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/POSTGRESQL\.host/, 'die: Missing POSTGRESQL.host value';

    throws_ok {
        my $text = q{
            [DB]
            engine = PostgreSQL

            [POSTGRESQL]
            host = zonemaster-host
            password = zonemaster_password
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/POSTGRESQL\.user/, 'die: Missing POSTGRESQL.user value';

    throws_ok {
        my $text = q{
            [DB]
            engine = PostgreSQL

            [POSTGRESQL]
            host = zonemaster-host
            user = zonemaster_user
            database = zonemaster_database
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/POSTGRESQL\.password/, 'die: Missing POSTGRESQL.password value';

    throws_ok {
        my $text = q{
            [DB]
            engine = PostgreSQL

            [POSTGRESQL]
            host = zonemaster-host
            user = zonemaster_user
            password = zonemaster_password
        };
        Zonemaster::Backend::Config->parse( $text );
    }
    qr/POSTGRESQL\.database/, 'die: Missing POSTGRESQL.database value';

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

    {
        my $path = catfile( dirname( $0 ), '..', 'share', 'backend_config.ini' );
        my $text = read_file( $path );
        lives_ok {
            Zonemaster::Backend::Config->parse( $text );
        } 'default config is valid';
    }

};
