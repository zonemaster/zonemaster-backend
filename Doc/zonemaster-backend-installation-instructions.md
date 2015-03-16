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
       libmodule-install-perl postgresql postgresql-contrib \
```
**Install CPAN dependencies**

```
$ sudo cpan -i JSON::RPC::Dispatch Plack::Middleware::Debug
```

**Build source code**
```
    $ perl Makefile.PL
    $ make test
```

Both these steps produce quite a bit of output. As long as it ends by printing `Result: PASS`, everything is OK.

```
    $ sudo make install
```

This too produces some output. The `sudo` command may not be necessary, if you normally have write permissions to your Perl installation.

**Create a log directory**
```
mkdir logs ## Path to your log directory and the directory name"
```
**In the directory add a file**
```
$ cd logs
$ touch backend_starman.log
$ touch execute_tests.log
```
**Database set up**
```
$ cd ..
```

Edit the file `share/backend_config.ini`. Once you have finished editing it,
either copy it manually to the directory `/etc/zonemaster`, or re-run the `make
install` step above.

```
engine           = PostgreSQL
user             = zonemaster
password         = zonemaster
database_name    = zonemaster
database_host    = localhost
polling_interval = 0.5
log_dir          = logs/
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
$ create user zonemaster  WITH PASSWORD 'zonemaster';
$ create database zonemaster;
$ GRANT ALL PRIVILEGES ON DATABASE zonemaster to zonemaster;
$ \q
$ exit
$ perl -MZonemaster::WebBackend::Engine -e 'Zonemaster::WebBackend::Engine->new({ db => "Zonemaster::WebBackend::DB::PostgreSQL"})->{db}->create_db()'
```

Only do this when you first install the Zonemaster backend. _If you do this on an existing system, you will wipe out the data in your database_.

**Starting starman**
```
$ starman --error-log=/home/user/logs/backend_starman.log --listen=127.0.0.1:5000 --pid=/home/user/logs/starman.pid --daemonize /usr/local/bin/zonemaster_webbackend.psgi
$ cat ~/logs/backend_starman.log ## To verify starman has started
```
**Add a crontab entry for the backend process launcher**

Add the following two lines to the crontab entry. Make sure to provide the
absolute directory path where the log file "execute_tests.log" exists. The
`execute_tests.pl` script will be installed in `/usr/local/bin`, so we make
sure that will be in cron's path.

```
$ crontab -e
PATH=/bin:/usr/bin:/usr/local/bin
*/15 * * * * execute_tests.pl >> /home/user/logs/execute_tests.log 2>&1
```