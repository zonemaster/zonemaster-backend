use strict;
use warnings;
use ExtUtils::MakeMaker;

sub MY::install {
    "install ::\n\t\$(info This makefile only supports the 'make dist', target)"
}

WriteMakefile(
    NAME                => 'zonemaster-backend',
    DISTVNAME		=> 'zonemaster-backend',
    AUTHOR              => q{Michal TOMA <toma@nic.fr>},
    VERSION_FROM        => 'Engine.pm',
    ABSTRACT            => 'The Zonemaster project Web Backend engine',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
	'Zonemaster' 			=> 0,

	'Config::IniFiles' 		=> 0,
	'Data::Dumper' 			=> 0,
	'DBI' 				=> 0,
	'DBD::Pg' 			=> 0,
	'DBD::mysql' 			=> 0,
	'DBD::SQLite'			=> 0,
	'Digest::MD5' 			=> 0,
	'Encode' 			=> 0,
	'File::Slurp' 			=> 0,
	'FindBin' 			=> 0,
	'HTML::Entities' 		=> 0,
	'IO::CaptureOutput' 		=> 0,
	'JSON' 				=> 0,
	'JSON::RPC::Dispatch' 		=> 0,
	'Locale::TextDomain' 		=> 0,
	'LWP::UserAgent' 		=> 0,
	'Moose' 			=> 0,
	'Moose::Role' 			=> 0,
	'Net::DNS' 			=> 0,
	'Net::DNS::SEC'			=> 0,
	'Net::IP' 			=> 0,
	'Net::LDNS' 			=> 0,
	'Plack::Builder' 		=> 0,
	'Plack::Middleware::Debug'	=> 0,
	'POSIX' 			=> 0,
	'Proc::ProcessTable' 		=> 0,
	'Router::Simple::Declare' 	=> 0,
	'Store::CouchDB' 		=> 0,
	'String::ShellQuote' 		=> 0,
	'Starman' 			=> 0,
	'Test::More' 			=> 0,
	'Time::HiRes' 			=> 0,
	
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'zonemaster-backend*' },
    test		=> { TESTS => 't/test01.t' },
);
