# Zonemaster Backend Installation instructions

The documentation covers the following operating systems:

 * Ubuntu 14.04 (LTS)

## Zonemaster Backend installation

### Instructions for Ubuntu 14.04

**To get the source code**

    $ sudo apt-get install git build-essential
    $ git clone https://github.com/dotse/zonemaster-backend.git

**Install package dependencies**

    $ sudo apt-get install libconfig-inifiles-perl libdata-dump-perl libdbi-perl \
      libdbd-pg-perl libdbd-mysql-perl libdigest-md5-file-perl libencode-locale-perl \
      libfile-slurp-perl libfindbin-libs-perl libhtml-parser-perl \
      libio-captureoutput-perl libjson-perl libjson-rpc-perl \
      libdist-zilla-localetextdomain-perl libtest-lwp-useragent-perl libmoose-perl \
      libcatalystx-simplelogin-perl libnet-dns-perl libnet-ip-perl libplack-perl \
      libproc-processtable-perl librouter-simple-perl libstring-shellquote-perl \
      libtest-most-perl libtime-hires-perl postgresql postgresql-contrib starman \
      couchdb dnssec-tools

**Install CPAN dependencies**

Unfortunately `Net::LDNS` has not been packaged for Ubuntu yet. So you need to
install this dependency from CPAN:

    $ sudo perl -MCPAN -e 'install Net::LDNS'

If all package dependencies are already installed from the previous section,
this should compile and install after configuration of your CPAN module
installer.

**Build source code**

    $ cd zonemaster-backend
    $ perl Makefile.PL
    Writing Makefile for Zonemaster-backend
    Writing MYMETA.yml and MYMETA.json
    $ make test
    $ sudo make install

**Database set up**

  * [DB]
  * engine=PostgreSQL (The backend database type to use. It can be either
PostgreSQL, MySQL, SQLite or CouchDB)
```
    user             = zonemaster ## The database username
    password         = zonemaster ## The database password
    database_name    = zonemaster ## The database name
    database_host    = localhost  ## The host where the database is accessible)
    polling_interval = 0.5        ## The frequency at which the database will be checked 
                                  ## by the backend process to see if any new domain test 
                                  ## requests are availble (in seconds).
```

  * [LOG]
```
    log_dir = /var/log/zonemaster/job_runner/ ## The place where the JobRunner logfiles 
                                              ## will be written
```
  * [PERL]
```
     interpreter = perl ## The full name of the perl interpreter 
                        ## for perlbrew based installations
```
  * [ZONEMASTER]
```
    max_zonemaster_execution_time             = 300 ## The delay after which a test process
                                                    ## will be considered hung and hard 
                                                    ## killed
    number_of_professes_for_frontend_testing  = 20  ## The maximum number of processes for 
                                                    ## frontend test requests
    number_of_professes_for_batch_testing     = 20  ## The maximum number of processes for
                                                    ## batch test requests
```
**Create the PostgreSQL Database**

    'psql --version' (Verify that PostgreSQL version is higher than 9.3)

  * A database with the name specified in the configuration file must be created and the database user must have table creation rights.
  * From the folder containing the Engine.pm module execute the command:
```
    $ perl -MEngine -e 'Engine->new({ db => "ZonemasterDB::PostgreSQL"})->{db}->create_db()'
```	
**Starting starman**

  * Start the backend using the Starman application server**
```
    $ sudo starman --error-log=/var/log/zonemaster/backend_starman.log --listen=127.0.0.1:5000 backend.psgi
```
  * Or on perlbrew based installations:*
```
    $ /home/user/perl5/perlbrew/perls/perl-5.20.0/bin/perl /home/user/perl5/perlbrew/perls/perl-5.20.0/bin/starman --error-log=/var/log/zonemaster/backend_starman.log --listen=127.0.0.1:5000 backend.psgi
```
  * Verification	
```
    $ perl client.pl
```	
**Add a crontab entry for the backend process luncher**
```
    /15 * * * * perl /home/user/zm_distrib/zonemaster-backend/JobRunner/execute_tests.pl >> /var/log/zonemaster/job_runner/execute_tests.log 2>&1
```
  *Or on perlbrew based installations:*
```
    /15 * * * * /home/user/perl5/perlbrew/perls/perl-5.20.0/bin/perl /home/user/zm_distrib/zonemaster-backend/JobRunner/execute_tests.pl >> /var/log/zonemaster/job_runner/execute_tests.log 2>&1
```	
