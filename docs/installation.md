# Zonemaster Backend Installation instructions

The documentation covers the following operating systems:

 * Ubuntu 14.04LTS

## Pre-Requisites

Zonemaster-engine should be installed before. Follow the instructions
[here](https://github.com/dotse/zonemaster/blob/master/docs/documentation/installation.md)

## Instructions for installing in Ubuntu 14.04

1) Install package dependencies

    sudo apt-get install git libmodule-install-perl libconfig-inifiles-perl \
    libdbd-sqlite3-perl starman libio-captureoutput-perl libproc-processtable-perl \
    libstring-shellquote-perl librouter-simple-perl libjson-rpc-perl \
    libclass-method-modifiers-perl libmodule-build-tiny-perl \
    libtext-microtemplate-perl libdaemon-control-perl

2) Install CPAN dependencies

    $ sudo cpan -i Plack::Middleware::Debug Parallel::ForkManager

3) Get the source code

    $ git clone https://github.com/dotse/zonemaster-backend.git

4) Build source code

    $ cd zonemaster-backend
    $ perl Makefile.PL
    $ make test

Both these steps produce quite a bit of output. As long as it ends by
printing `Result: PASS`, everything is OK.

5) Install 

    $ sudo make install

This too produces some output. The `sudo` command may not be necessary,
if you normally have write permissions to your Perl installation.

6) Create a log directory

Path to your log directory and the directory name:

    $ cd ~/
    $ mkdir logs

Note: The Perl module `Parallel::ForkManager` exists as a Debian package, but with a version too old to be useful for us.

## Database set up

### Using PostgreSQL as database for the backend

1) install PostgreSQL packages.

    sudo apt-get install libdbd-pg-perl postgresql

2) Edit the file `zonemaster-backend/share/backend_config.ini`. Once you have
finished editing it, copy it to the directory `/etc/zonemaster`. You will
probably have to create the directory first.

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

3) PostgreSQL Database manipulation

Verify that PostgreSQL version is 9.3 or higher:

    $ psql --version

4) Connect to Postgres as a user with administrative privileges and set things up:

    $ sudo su - postgres
    $ psql < /home/<user>/zonemaster-backend/docs/initial-postgres.sql

This creates a database called `zonemaster`, as well as a user called "zonemaster" with the password "zonemaster" (as stated in the config file). This user has just enough permissions to run the backend software.

If, at some point, you want to delete all traces of Zonemaster in the database, you can run the file `docs/cleanup-postgres.sql` as a database administrator. It removes the user and drops the database (obviously taking all data with it).

### Using MySQL as database for the backend

1) Install MySQL packages.

    sudo apt-get install mysql-server-5.6 libdbd-mysql-perl

2) Edit and copy the `backend_config.ini` file as for the PostgreSQL case, except on the `engine` line write `MySQL` instead.

3) Using a database adminstrator user (called root in the example below), run the setup file:
    
    mysql --user=root --password < docs/initial-mysql.sql
    
This creates a database called `zonemaster`, as well as a user called "zonemaster" with the password "zonemaster" (as stated in the config file). This user has just enough permissions to run the backend software.

If, at some point, you want to delete all traces of Zonemaster in the database, you can run the file `docs/cleanup-mysql.sql` as a database administrator. It removes the user and drops the database (obviously taking all data with it).

### Starting the backend

#### General instructions

1) In all the examples below, replace `/home/user` with the path to your own home
directory (or, of course, wherever you want).

    $ starman --error-log=/home/user/logs/backend_starman.log \
      --listen=127.0.0.1:5000 --pid=/home/user/logs/starman.pid \
      --daemonize /usr/local/bin/zonemaster_webbackend.psgi

2) To verify starman has started:

    $ cat ~/logs/backend_starman.log

3) If you would like to kill the starman process, you can issue this command:

    $ kill `cat /home/user/logs/starman.pid`

#### Ubuntu 14.04LTS

These specific instructions can be used at least for Ubuntu 14.04LTS, and probably also for other systems using `upstart`.

1) Copy the file `share/starman-zonemaster.conf` to the directory `/etc/init`.

2) Run `sudo service starman-zonemaster start`.

This only needs to be run as root in order to make sure the log file can be opened. The `starman` process will change to the `www-data` user as soon as it can, and all of the real work will be done as that user.

### Start the backend process launcher

To start it manually, do this:

    zm_wb_daemon --pidfile=/tmp/zm_wb_daemon.pid start

In order to have it done automatically, you can use the example Upstart config file in `share/zm_wb_daemon.conf` (for Ubuntu 14.04 and similar), or insert the command above into your system's startup sequence in some other appropriate way. The only permission needed is to write the PID file.

## Testing the setup

You can look into the [API documentation](API.md) to see how you can use the
API for your use. If you followed the instructions to the minute, you should
be able to use the API och localhost port 5000, like this:

    $ curl -H "Content-Type: application/json" \
      -d '{"params":"","jsonrpc":"2.0","id":140715758026879,"method":"version_info"}' \
     http://localhost:5000/

The response should be something like this:

    {"id":140715758026879,"jsonrpc":"2.0","result":"Zonemaster Test Engine Version: v1.0.2"}

### All done


Next step is to install the [Web UI](https://github.com/dotse/zonemaster-gui/blob/master/Zonemaster_Dancer/Doc/zonemaster-frontend-installation-instructions.md) if you wish so.


