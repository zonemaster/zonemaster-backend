#Zonemaster Backend Installation instructions

##Description of required the files

./Engine.pm
	The main module

./backend.psgi
	The Plack/PSGI module. The main entry module for a Plack/PSGI server (like Starman)

./BackendConfig.pm
	The Configuration file abstraction layer

./backend_config.ini
	A sample configuration file

./Client.pm
./client.pl
	A sample script and library to communicate with the backend.

./ZonemasterDB.pm
	The Database abstraction layer.

./ZonemasterDB/MySQL.pm
	The Database abstraction layer MySQL sample backend.

./ZonemasterDB/SQLite.pm
	The Database abstraction layer SQLite sample backend.

./ZonemasterDB/PostgreSQL.pm
	The Database abstraction layer PostgreSQL backend.

./ZonemasterDB/CouchDB.pm
	The Database abstraction layer PostgreSQL sample backend.

./BackendTranslator.pm
	The transaltion module.

./JobRunner/README.txt
	The JobRunner module description file.

./JobRunner/Runner.pm
	The JobRunner main module.

./JobRunner/execute_zonemaster_P10.pl
./JobRunner/execute_zonemaster_P5.pl
	The scripts to execute tests with differents priorities (application level priorities).

./JobRunner/execute_tests.pl
	The main JobRunner entry point to execute from crontab.

./t/test01.t
./t/test02.t
./t/test_mysql_backend.t
./t/test_validate_syntax.t
./t/test03.t
	Test files.

##Install Perl dependencies
	Zonemaster

	Config::IniFiles
	Data::Dumper
	DBI
	Digest::MD5
	Encode
	File::Slurp
	FindBin
	HTML::Entities
	IO::CaptureOutput
	JSON
	JSON::RPC::Dispatch
	Locale::TextDomain
	LWP::UserAgent
	Moose
	Moose::Role
	Net::DNS
	Net::IP
	Net::LDNS
	Plack::Builder
	POSIX
	Proc::ProcessTable
	Router::Simple::Declare
	Store::CouchDB
	String::ShellQuote
	Srtarman
	Test::More
	Time::HiRes

#edit the configuration file backend_config.ini and copy to /etc/zonemaster/

	* [DB]
	* engine=PostgreSQL
		The backend database type to use. Can be either PostgreSQL, MySQL, SQLite or CouchDB

	* user=zonemaster
		The database username
		
	* password=zonemaster
		The database password
		
	* database_name=zonemaster
		The database name
		
	* database_host=localhost
		The host where the database is accessible
		
	* polling_interval=0.5
		The frequency at which the tafabase will be checked by the backend process to see if any new domain test requests are availble (in seconds).

	* [LOG]
	* log_dir=/var/log/zonemaster/job_runner/
		The place where the JobRunner logfiles will be written

	* [PERL]
	* interpreter=perl
		The full name of the perl interpreter (for perlbrew based installations)

	* [ZONEMASTER]
	* max_zonemaster_execution_time=300
		The delay after which a test process will be considered hung and hard killed.
		
	* number_of_professes_for_frontend_testing=20;
		The maximum number of processes for frontend test requests
		
	* number_of_professes_for_batch_testing=20;
		The maximum number of processes for batch test requests

#Create the PostgreSQL Database
	- PostgreSQL 9.3 or higher is required
	- A database with the name specified in the configuration file must be created and the database user must have table creation rights.
	- From the folder containing the Engine.pm module execute the command: perl -MEngine -e 'Engine->new({ db => "ZonemasterDB::PostgreSQL"})->{db}->create_db()'
	
#Start the backend using the Starman application server
	- starman --error-log=/var/log/zonemaster/backend_starman.log --listen=127.0.0.1:5000 backend.psgi
	
	or on perlbrew based installations:
	- /home/user/perl5/perlbrew/perls/perl-5.20.0/bin/perl /home/user/perl5/perlbrew/perls/perl-5.20.0/bin/starman --error-log=/var/log/zonemaster/backend_starman.log --listen=127.0.0.1:5000 backend.psgi
	
#make a test with the client.pl script
	- simply run perl client.pl and look for any errors.
	
#add a crontab entry for the backend process luncher
	*/15 * * * * perl /home/user/zm_distrib/zonemaster-backend/JobRunner/execute_tests.pl >> /var/log/zonemaster/job_runner/execute_tests.log 2>&1

	or on perlbrew based installations:
	*/15 * * * * /home/user/perl5/perlbrew/perls/perl-5.20.0/bin/perl /home/user/zm_distrib/zonemaster-backend/JobRunner/execute_tests.pl >> /var/log/zonemaster/job_runner/execute_tests.log 2>&1
	