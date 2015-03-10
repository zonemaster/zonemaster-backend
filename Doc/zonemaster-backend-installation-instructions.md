# Zonemaster Backend Installation instructions

The documentation covers the following operating systems:

 * [Ubuntu 14.0.4 LTS](#q1)

## Zonemaster Backend installation

### Pre-Requisites

Zonemaster-engine should be installed before. Follow the instructions
[here](https://github.com/dotse/zonemaster/blob/master/docs/documentation/installation.md)

### Instructions for Ubuntu 14.04 with PostgreSQL as the database 

**To get the source code**

    $ git clone https://github.com/dotse/zonemaster-backend.git

**Install package dependencies**

```
sudo apt-get install libintl-perl libwww-perl libmoose-perl \
       libnet-dns-perl libnet-dns-sec-perl libnet-ip-perl libplack-perl \
       libproc-processtable-perl librouter-simple-perl \
       libstring-shellquote-perl starman libconfig-inifiles-perl \
       libdbi-perl libdbd-sqlite3-perl libdbd-pg-perl \
       libfile-slurp-perl libhtml-parser-perl libio-captureoutput-perl \
       libjson-perl libintl-perl libmoose-perl libnet-dns-perl \
       postgresql postgresql-contrib \
```
**Install CPAN dependencies**

```
$ sudo cpan -i JSON::RPC::Dispatch Plack::Middleware::Debug
```

**Modifying the Makefile**
```
cd zonemaster-backend
```
Remove the following lines from the makefile "Makefile.PL"
```
'DBD::mysql' => 0,
'Store::CouchDB' => 0,
```
**Build source code**
```
    $ perl Makefile.PL
    Writing Makefile for Zonemaster-backend
    Writing MYMETA.yml and MYMETA.json
    $ make
    $ make test
```
**Create a log directory**
```
mkdir "Path to your log directory and the directory name"
```
**Database set up**

Edit the file "backend_config.ini"

```
engine           =PostgreSQL
user             = zonemaster
password         = zonemaster
database_name    = zonemaster
database_host    = localhost
polling_interval = 0.5
log_dir          = "Path to your log directory"
interpreter      = perl
max_zonemaster_execution_time   = 300
number_of_professes_for_frontend_testing  = 20
number_of_professes_for_batch_testing     = 20
```

**PostgreSQL Database manipulation**
```
$ psql --version (Verify that PostgreSQL version is higher than 9.3)

**Connect to Postgres for the first time and create the database and user**

$ sudo su - postgres
$ psql
$ createuser zonemaster  WITH PASSWORD 'zonemaster';
$ create database zonemaster;
$ GRANT ALL PRIVILEGES ON DATABASE zonemaster to zonemaster;
```

**From the folder containing the Engine.pm module execute the command:**
```
 $ perl -MEngine -e 'Engine->new({ db => "ZonemasterDB::PostgreSQL"})->{db}->create_db()'
```
*Ignore the notice response which results as the output of the above command*

**Starting starman**
```
$ sudo starman --error-log="Path to your log file" --listen=127.0.0.1:5000 backend.psgi
```
**Add a crontab entry for the backend process launcher**
```
*/15 * * * * perl /home/user/zm_distrib/zonemaster-backend/JobRunner/execute_tests.pl >> "Path to your log direcroty"/execute_tests.log 2>&1
```



