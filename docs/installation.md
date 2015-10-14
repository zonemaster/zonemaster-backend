# Zonemaster Backend Installation instructions

The documentation covers the following operating systems:

 * [1] <a href="#Debian">Ubuntu 14.04 (LTS)</a>
 * [2] <a href="#Debian">Debian Wheezy (version 7)</a>
 * [3] <a href="#FreeBSD">FreeBSD 10</a>

## Pre-Requisites

Zonemaster-engine should be installed before. Follow the instructions
[here](https://github.com/dotse/zonemaster/blob/master/docs/documentation/installation.md)

## <a name="Debian"></a> Instructions for installing in Ubuntu 14.04 and Debian wheezy (version 7)

1) Install package dependencies

    sudo apt-get install git libmodule-install-perl libconfig-inifiles-perl \
    libdbd-sqlite3-perl starman libio-captureoutput-perl libproc-processtable-perl \
    libstring-shellquote-perl librouter-simple-perl libclass-method-modifiers-perl \
    libtext-microtemplate-perl libdaemon-control-perl 

2) Install CPAN dependencies

    $ sudo cpan -i Plack::Middleware::Debug Parallel::ForkManager JSON::RPC

Note: The Perl modules `Parallel::ForkManager` and `JSON::RPC` exist as Debian packages, but with versions too old to be useful for us.

3) Get the source code

    $ git clone https://github.com/dotse/zonemaster-backend.git

4) Build source code

    $ cd zonemaster-backend
    $ perl Makefile.PL
    $ make
    $ make test

Both these steps produce quite a bit of output. As long as it ends by
printing `Result: PASS`, everything is OK.

5) Install 

    $ sudo make install

This too produces some output. The `sudo` command may not be necessary,
if you normally have write permissions to your Perl installation.

## Database set up

### Using PostgreSQL as database for the backend

1) Create a directory 

    $ sudo mkdir /etc/zonemaster

2) Edit the file `share/backend_config.ini` in the `zonemaster-backend`
directory

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

3) Copy the `backend_config.ini` file to `/etc/zonemaster`

    $ sudo cp share/backend_config.ini /etc/zonemaster

4) PostgreSQL Database manipulation for **Ubuntu**

Verify that PostgreSQL version is 9.3 or higher:

    $ psql --version

5) PostgreSQL Database manipulation for **Debian**

Note: the default Debian package repository does not have a recent enough PostgreSQL server version. If you're using Debian, you'll either have to use an external database, install from another repository or use the MySQL backend.

5.1) Add the following to the source list "/etc/apt/sources.list"

    deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main

5.2) $ wget https://www.postgresql.org/media/keys/ACCC4CF8.asc

5.3) $ apt-key add ACCC4CF8.asc

5.4) apt-get update

5.5) Verify that PostgreSQL version is 9.3 or higher:

    $ psql --version

6) install PostgreSQL packages.

    sudo apt-get install libdbd-pg-perl postgresql

7) Connect to Postgres as a user with administrative privileges and set things up:

    $ sudo su - postgres
    $ psql -f /home/<user>/zonemaster-backend/docs/initial-postgres.sql

This creates a database called `zonemaster`, as well as a user called "zonemaster" with the password "zonemaster" (as stated in the config file). This user has just enough permissions to run the backend software.

If, at some point, you want to delete all traces of Zonemaster in the database,
you can run the file `docs/cleanup-postgres.sql` in the `zonemaster-backend`
directory as a database administrator. It removes the user and drops the database (obviously taking all data with it).

8) Exit PostgreSQL

   $ exit

### Using MySQL as database for the backend

1) Create a directory 

    $ sudo mkdir /etc/zonemaster

2) Edit the file `share/backend_config.ini`

    engine           = MySQL
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

3)  Copy the `backend_config.ini` file to `/etc/zonemaster`

    $ sudo cp share/backend_config.ini /etc/zonemaster

4) Install MySQL packages.

    $ sudo apt-get install mysql-server libdbd-mysql-perl

5) Using a database adminstrator user (called root in the example below), run the setup file:
    
    $ mysql --user=root --password < docs/initial-mysql.sql
    
This creates a database called `zonemaster`, as well as a user called "zonemaster" with the password "zonemaster" (as stated in the config file). This user has just enough permissions to run the backend software.

If, at some point, you want to delete all traces of Zonemaster in the database, you can run the file `docs/cleanup-mysql.sql` as a database administrator. It removes the user and drops the database (obviously taking all data with it).

### Starting the backend

#### General instructions

1) Create a log directory

Path to your log directory and the directory name:

    $ cd ~/
    $ mkdir logs

2) In all the examples below, replace `/home/user` with the path to your own home
directory (or, of course, wherever you want).

    $ starman --error-log=/home/user/logs/backend_starman.log \
      --listen=127.0.0.1:5000 --pid=/home/user/logs/starman.pid \
      --daemonize /usr/local/bin/zonemaster_webbackend.psgi

3) To verify starman has started:

    $ cat ~/logs/backend_starman.log

4) If you would like to kill the starman process, you can issue this command:

    $ kill `cat /home/user/logs/starman.pid`

#### Starting the starman part that listens for and answers the JSON::RPC
requests (**Ubuntu 14.04LTS**)

These specific instructions can be used at least for Ubuntu 14.04LTS, and probably also for other systems using `upstart`.

1) Copy the file `share/starman-zonemaster.conf` to the directory `/etc/init`.

    $ sudo cp share/starman-zonemaster.conf /etc/init

2) Run `sudo service starman-zonemaster start`

    $ sudo service starman-zonemaster start

This only needs to be run as root in order to make sure the log file can be opened. The `starman` process will change to the `www-data` user as soon as it can, and all of the real work will be done as that user.

#### Starting the starman part that listens for and answers the JSON::RPC
requests (**Debian**)

1)  Copy the file `share/zm-backend.sh` to the directory `/etc/init`.

    $ sudo cp share/zm-backend.sh /etc/init.d/

2)  Make it an executable file

    $ sudo chmod +x /etc/initd.d/zm-backend.sh

3)  Add the file to start up script

    $ sudo update-rc.d zm-backend.sh defaults

4)  Start the process

    $ sudo service zm-backend.sh start

This only needs to be run as root in order to make sure the log file can be
opened. The `starman` process will change to the `www-data` user as soon as it
can, and all of the real work will be done as that user.


### Start the backend process launcher for the database

To start it manually, do this:

    zm_wb_daemon --pidfile=/tmp/zm_wb_daemon.pid start

In order to have it done automatically, you can use the example Upstart config file in `share/zm_wb_daemon.conf` (for Ubuntu 14.04 and similar), or insert the command above into your system's startup sequence in some other appropriate way. The only permission needed is to write the PID file.

There is an LSB-compatible example startup file in `share/zm-backend.sh`. As distributed, it is set up to depend on the MySQL database server being started before it. You may need to change that to PostgreSQL if that's what you're using, or remove it entirely if you're using a separate database server. There are also a user name, a group name and a couple of directories that you may need to edit. Once that is done and the script file copied to `/etc/init.d`, at least on Debian 7 it should be possible to start both the backend server processes with the single command `service zm-backend.sh start`.

The script should also serve as a base for other operating systems using SysV init.d startup scripts.

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



## <a name="FreeBSD"></a> FreeBSD 10.0 & 10.1 Instructions

First, make sure your operating system and package database is up to date.

1) Become root

    su -

2) Install packages

    pkg install p5-Config-IniFiles p5-DBI p5-File-Slurp p5-HTML-Parser p5-IO-CaptureOutput p5-JSON p5-JSON-RPC p5-Locale-libintl p5-libwww p5-Moose p5-Plack p5-Router-Simple p5-String-ShellQuote p5-Starman p5-File-ShareDir p5-Parallel-ForkManager p5-Daemon-Control p5-Module-Install p5-DBD-SQLite p5-Plack-Middleware-Debug

3) Get and build the source code

    git clone https://github.com/dotse/zonemaster-backend.git
    cd zonemaster-backend
    perl Makefile.PL
    make
    make test
    make install

### Database installation and setup (currently PostgreSQL and MySQL supported)

4.1) PostgreSQL

    sudo pkg install postgresql93-server p5-DBD-Pg

4.1) Start the PostgreSQL server according to its instructions then initiate the database using the following script.

    psql -U pgsql template1 -f docs/initial-postgres.sql

4.2) MySQL

    pkg install mysql56-server p5-DBD-mysql

4.2) Start the MySQL server according to its instructions then initiate the database using the following script.

    mysql -uroot < docs/initial-mysql.sql

5) Configure Zonemaster-Backend to use the chosen database

    mkdir -p /etc/zonemaster
    cp share/backend_config.ini /etc/zonemaster/

6) Edit the "engine" line to match the chosen database, MySQL and PostgreSQL supported.

   vi /etc/zonemaster/backend_config.ini

7) Start the processes, point pid and log to a appropriate-for-your-OS location (first line is the API second is the test runner itself)

    starman --error-log=/home/user/logs/error.log --pid-file=/home/user/logs/starman.pid --listen=127.0.0.1:5000 --daemonize /usr/local/bin/zonemaster_webbackend.psgi
    zm_wb_daemon start

## CentOS instructions

1) Install the Zonemaster test engine according to its instructions.

2) Add packages.
    
    sudo yum install perl-Module-Install perl-IO-CaptureOutput perl-String-ShellQuote

3) Install modules from CPAN.
    
    sudo cpan -i Config::IniFiles Daemon::Control JSON::RPC::Dispatch Parallel::ForkManager Plack::Builder Plack::Middleware::Debug Router::Simple::Declare Starman

4) Fetch the source code.
    
    git clone https://github.com/dotse/zonemaster-backend.git
    cd zonemaster-backend

5) Build and install the backend modules.
    
    perl Makefile.PL && make test && sudo make install

6) Install a database server. MySQL, in this example.
    
    sudo yum install wget
    wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
    sudo rpm -ivh mysql-community-release-el7-5.noarch.rpm
    sudo yum install mysql-server perl-DBD-mysql
    sudo systemctl start mysqld

7) Set up the database.
    
    mysql -uroot < docs/initial-mysql.sql

8) Copy the example init file to the system directory. You may wish to edit the file in order to use a more suitable user and group. As distributed, it uses the MySQL user and group, since we can be sure that exists and it shouldn't mess up anything included with the system.
    
    sudo cp share/zm-centos.sh /etc/init.d/
    sudo chmod +x /etc/init.d/zm-centos.sh

9) Start the services.
    
    sudo systemctl start zm-centos

10) Test that it started OK. The command below should print a JSON string including some information on the Zonemaster engine version.
    
    curl -X POST http://127.0.0.1:5000/ -d '{"method":"version_info"}'
