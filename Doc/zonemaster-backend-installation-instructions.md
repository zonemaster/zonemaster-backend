# Zonemaster Backend Installation instructions

The documentation covers the following operating systems:

 * [Ubuntu 14.04LTS](#q1)

## Zonemaster Backend installation

### Pre-Requisites

Zonemaster-engine should be installed before. Follow the instructions
[here](https://github.com/dotse/zonemaster/blob/master/docs/documentation/installation.md)

### Instructions for Ubuntu 14.04 with PostgreSQL as the database 

**Install package dependencies**

```
sudo apt-get install git libmodule-install-perl libconfig-inifiles-perl \
                     libdbd-sqlite3-perl starman libio-captureoutput-perl \
                     libproc-processtable-perl libstring-shellquote-perl \
                     librouter-simple-perl libjson-rpc-perl \
                     libclass-method-modifiers-perl libmodule-build-tiny-perl \
                     libtext-microtemplate-perl libdbd-pg-perl postgresql
```

**Install CPAN dependency**

```
$ sudo cpan -i Plack::Middleware::Debug
```

**Get the source code**

    $ git clone https://github.com/dotse/zonemaster-backend.git

**Build source code**
```
    $ cd zonemaster-backend
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
cd ~/
mkdir logs ## Path to your log directory and the directory name"
```

**Database set up**

Edit the file `zonemaster-backend/share/backend_config.ini`. Once you have finished editing it,
copy it to the directory `/etc/zonemaster`. You will probably have to create
the directory first.

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
$ psql --version (Verify that PostgreSQL version is 9.3 or higher)

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

In all the examples below, replace `/home/user` with the path to your own home
directory (or, of course, wherever you want).

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

## All done

At this point, you no longer need the checked out source repository (unless you chose to put the log files there, of course).