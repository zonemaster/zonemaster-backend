# Zonemaster Backend Installation instructions

The documentation covers the following operating systems:

 * Ubuntu 14.04LTS

## Zonemaster Backend installation

### Pre-Requisites

Zonemaster-engine should be installed before. Follow the instructions
[here](https://github.com/dotse/zonemaster/blob/master/docs/documentation/installation.md)

### Instructions for Ubuntu 14.04 with PostgreSQL as the database 

**Install package dependencies**

```
sudo apt-get install git libmodule-install-perl libconfig-inifiles-perl 
libdbd-sqlite3-perl starman libio-captureoutput-perl libproc-processtable-perl 
libstring-shellquote-perl librouter-simple-perl libjson-rpc-perl 
libclass-method-modifiers-perl libmodule-build-tiny-perl  libtext-microtemplate-perl 
libdbd-pg-perl postgresql
```

**Install CPAN dependency**

    $ sudo cpan -i Plack::Middleware::Debug


**Get the source code**

    $ git clone https://github.com/dotse/zonemaster-backend.git


**Build source code**
```
    $ cd zonemaster-backend
    $ perl Makefile.PL
    $ make test
```

Both these steps produce quite a bit of output. As long as it ends by
printing `Result: PASS`, everything is OK.

    $ sudo make install

This too produces some output. The `sudo` command may not be necessary,
if you normally have write permissions to your Perl installation.

**Create a log directory**

Path to your log directory and the directory name:

    $ cd ~/
    $ mkdir logs

**Database set up**

Edit the file *`zonemaster-backend/share/backend_config.ini`*. Once you have
finished editing it, copy it to the directory `*/etc/zonemaster*`. You will
probably have to create the directory first.

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

Verify that PostgreSQL version is 9.3 or higher:

    $ psql --version

**Connect to Postgres for the first time and create the database and user**

    $ sudo su - postgres
    $ psql < /home/<user>/zonemaster-backend/docs/initial-postgres.sql
    $ exit

Then let the Backend set up your schema:
```
    $ perl -MZonemaster::WebBackend::Engine -e 'Zonemaster::WebBackend::Engine->new({ db => "Zonemaster::WebBackend::DB::PostgreSQL"})->{db}->create_db()'
```
Only do this during an initial installation of the Zonemaster backend.

_If you do this on an existing system, you will wipe out the data in your
database_.


**Starting starman**

In all the examples below, replace `*/home/user*` with the path to your own home
directory (or, of course, wherever you want).

```
    $ starman --error-log=/home/user/logs/backend_starman.log \
      --listen=127.0.0.1:5000 --pid=/home/user/logs/starman.pid \
      --daemonize /usr/local/bin/zonemaster_webbackend.psgi
```

To verify starman has started:

    $ cat ~/logs/backend_starman.log

If you would like to kill the starman process, you can issue this command:

    $ kill `cat /home/user/logs/starman.pid`

**Add a crontab entry for the backend process launcher**

Add the following two lines to the crontab entry. Make sure to provide the
absolute directory path where the log file "execute_tests.log" exists. The
`execute_tests.pl` script will be installed in `/usr/local/bin`, so we make
sure that will be in cron's path.

```
$ PATH=/bin:/usr/bin:/usr/local/bin
$ crontab -e
*/15 * * * * execute_tests.pl >> /home/user/logs/execute_tests.log 2>&1
```

## All done

At this point, you no longer need the checked out source repository (unless
you chose to put the log files there, of course).

Next step is to install the [Web
UI]((https://github.com/dotse/zonemaster-gui/blob/master/Zonemaster_Dancer/Doc/zonemaster-frontend-installation-instructions.md) if you wish so.


## Testing the setup

You can look into the [API documentation](API.md) to see how you can use the
API for your use. If you followed the instructions to the minute, you should
be able to use the API och localhost port 5000, like this:

    $ curl -H "Content-Type: application/json" \
      -d '{"params":"","jsonrpc":"2.0","id":140715758026879,"method":"version_info"}' \
     http://localhost:5000/

The response should be something like this:

    {"id":140715758026879,"jsonrpc":"2.0","result":"Zonemaster Test Engine Version: v1.0.2"}
