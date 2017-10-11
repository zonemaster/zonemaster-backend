use inc::Module::Install;

name 'Zonemaster-Backend';
author q{Michal TOMA <toma@nic.fr>};
version_from 'lib/Zonemaster/Backend.pm';
abstract 'The Zonemaster Backend project with RPC API and Test Agents';
license 'perl';
perl_version '5.014002';

requires
  'Zonemaster::Engine'       => 2.0,
  'Config::IniFiles'         => 0,
  'DBI'                      => 1.616,
  'File::Slurp'              => 0,
  'HTML::Entities'           => 0,
  'IO::CaptureOutput'        => 0,
  'JSON::PP'                 => 0,
  'JSON::RPC::Dispatch'      => 0,
  'Locale::TextDomain'       => 0,
  'LWP::UserAgent'           => 0,
  'Moose'                    => 2.04,
  'Moose::Role'              => 0,
  'Net::IP::XS'              => 0.14,
  'Zonemaster::LDNS'         => 1.0,
  'Plack::Builder'           => 0,
  'Plack::Middleware::Debug' => 0,
  'Router::Simple::Declare'  => 0,
  'String::ShellQuote'       => 0,
  'Starman'                  => 0,
  'File::ShareDir'           => 0,
  'Parallel::ForkManager'    => 1.12,
  'Daemon::Control'          => 0,
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
