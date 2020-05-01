use inc::Module::Install;

name 'Zonemaster-Backend';
all_from 'lib/Zonemaster/Backend.pm';
repository 'https://github.com/zonemaster/zonemaster-backend';
bugtracker 'https://github.com/zonemaster/zonemaster-backend/issues';

requires
  'Class::Method::Modifiers'    => 1.09,
  'Config::IniFiles'            => 0,
  'DBI'                         => 1.616,
  'Daemon::Control'             => 0.001007,
  'File::ShareDir'              => 0,
  'File::Slurp'                 => 0,
  'HTML::Entities'              => 0,
  'IO::CaptureOutput'           => 0,
  'JSON::PP'                    => 0,
  'JSON::RPC'                   => 1.01,
  'JSON::Validator'             => 3.12,
  'Log::Any'                    => 0,
  'Log::Any::Adapter::Dispatch' => 0,
  'Log::Dispatch'               => 0,
  'Moose'                       => 2.04,
  'Net::IP::XS'                 => 0.14,
  'Parallel::ForkManager'       => 1.12,
  'Plack::Builder'              => 0,
  'Plack::Middleware::Debug'    => 0.14,
  'Role::Tiny'                  => 1.001003,
  'Router::Simple::Declare'     => 0,
  'Starman'                     => 0,
  'String::ShellQuote'          => 0,
  'Try::Tiny'                   => 0.30,
  'Zonemaster::Engine'          => 3.0,
  'Zonemaster::LDNS'            => 2.0,
  ;

test_requires 'DBD::SQLite';

recommends 'DBD::mysql';
recommends 'DBD::Pg';
recommends 'DBD::SQLite';

install_share;

install_script 'zonemaster_backend_rpcapi.psgi';
install_script 'zonemaster_backend_testagent';

no_index directory => 'CodeSnippets';
no_index directory => 'Doc';

WriteAll;
