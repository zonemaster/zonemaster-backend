# Zonemaster Backend installation guide

This document begins with a number of sections concerning native installation:

* [Prerequisites](#prerequisites)
* [Dependencies](#dependencies)
* [Installation](#installation)
* [Configuration](#configuration)
* [Startup](#startup)
* [Post-installation sanity check](#post-installation-sanity-check)
* [What's next](#whats-next)

This document ends with these appendices:

* [Quick installation using a Docker container](#quick-installation-using-a-docker-container)
* [Administrative tasks](#administrative-tasks)


## Prerequisites

This installation guide assumes that the following softwares are already installed on the target system:

* one of CentOS, Debian, FreeBSD or Ubuntu
* sudo
* curl (only for post-installation sanity check)


## Dependencies

*Zonemaster Engine* should be installed before. Follow the instructions
[here](https://github.com/dotse/zonemaster-engine/blob/master/docs/installation.md).


### Installing dependencies on CentOS

```sh
sudo yum install perl-Module-Install perl-IO-CaptureOutput perl-String-ShellQuote
sudo cpan -i Config::IniFiles Daemon::Control JSON::RPC::Dispatch Parallel::ForkManager Plack::Builder Plack::Middleware::Debug Router::Simple::Declare Starman
```


#### Installing dependencies for MySQL on CentOS

```sh
sudo yum install wget
wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
sudo rpm -ivh mysql-community-release-el7-5.noarch.rpm
sudo yum install mysql-server perl-DBD-mysql
sudo systemctl start mysqld
```


#### Installing dependencies for PostgreSQL on CentOS

Setting up Zonemaster Backend with PostgreSQL on CentOS is not supported at this time.


### Installing dependencies on Debian and Ubuntu

```sh
sudo apt-get update
sudo apt-get install git libmodule-install-perl libconfig-inifiles-perl libdbd-sqlite3-perl starman libio-captureoutput-perl libproc-processtable-perl libstring-shellquote-perl librouter-simple-perl libclass-method-modifiers-perl libtext-microtemplate-perl libdaemon-control-perl 
sudo cpan -i Plack::Middleware::Debug Parallel::ForkManager JSON::RPC
```

Note: The Perl modules `Parallel::ForkManager` and `JSON::RPC` exist as Debian packages, but with versions too old to be useful for us.


#### Installing dependencies for MySQL on Debian and Ubuntu

```sh
sudo apt-get install mysql-server libdbd-mysql-perl
```


#### Installing dependencies for PostgreSQL on Debian and Ubuntu

```sh
sudo apt-get install libdbd-pg-perl postgresql
```


### Installing dependencies on FreeBSD

```sh
sudo pkg install p5-Config-IniFiles p5-DBI p5-File-Slurp p5-HTML-Parser p5-IO-CaptureOutput p5-JSON p5-JSON-RPC p5-Locale-libintl p5-libwww p5-Moose p5-Plack p5-Router-Simple p5-String-ShellQuote p5-Starman p5-File-ShareDir p5-Parallel-ForkManager p5-Daemon-Control p5-Module-Install p5-DBD-SQLite p5-Plack-Middleware-Debug
```


#### Installing dependencies for MySQL on FreeBSD

```sh
sudo pkg install mysql56-server p5-DBD-mysql
```


#### Installing dependencies for PostgreSQL on FreeBSD

```sh
sudo pkg install postgresql93-server p5-DBD-Pg
```


## Installation

### Fetch the source code

```sh
git clone https://github.com/dotse/zonemaster-backend.git
cd zonemaster-backend
```


### Build source code

```sh
perl Makefile.PL
make
make test
```

These steps produce quite a bit of output. As long as it ends by
printing `Result: PASS`, everything is OK.


### Install 

```sh
sudo make install
```

This too produces some output. The `sudo` command may not be necessary,
if you normally have write permissions to your Perl installation.


## Configuration

Create directories for configuration and log files.

```sh
sudo mkdir /etc/zonemaster
mkdir "$HOME/logs"
```

Copy the `backend_config.ini` file to `/etc/zonemaster`.

```sh
sudo cp share/backend_config.ini /etc/zonemaster/
```


#### Installing service scripts on CentOS

Copy the example init file to the system directory. You may wish to edit the file in order to use a more suitable user and group. As distributed, it uses the MySQL user and group, since we can be sure that exists and it shouldn't mess up anything included with the system.

```sh
sudo cp share/zm-centos.sh /etc/init.d/
sudo chmod +x /etc/init.d/zm-centos.sh
```


#### Installing service scripts on Debian and Ubuntu

Copy the file `share/zm-backend.sh` to the directory `/etc/init`, make it an executable file, and add the file to start up script.

```sh
sudo cp share/zm-backend.sh /etc/init.d/
sudo chmod +x /etc/init.d/zm-backend.sh
sudo update-rc.d zm-backend.sh defaults
```


#### Installing service scripts on FreeBSD

Running Zonemaster Backend as a service on FreeBSD is not supported at this time.


### Configuring and creating a database in MySQL

Edit the file `/etc/zonemaster/backend_config.ini`.

```
engine           = MySQL
user             = zonemaster
password         = zonemaster
database_name    = zonemaster
database_host    = localhost
polling_interval = 0.5
log_dir          = logs/
interpreter      = perl
max_zonemaster_execution_time   = 300
number_of_processes_for_frontend_testing  = 20
number_of_processes_for_batch_testing     = 20
```

Using a database adminstrator user (called root in the example below), run the setup file:

```sh
mysql --user=root --password < docs/initial-mysql.sql
```

This creates a database called `zonemaster`, as well as a user called "zonemaster" with the password "zonemaster" (as stated in the config file). This user has just enough permissions to run the backend software.


### Configuring and creating a database in PostgreSQL

Edit the file `/etc/zonemaster/backend_config.ini`.

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
number_of_processes_for_frontend_testing  = 20
number_of_processes_for_batch_testing     = 20
```


#### Configuring PostgreSQL on CentOS

Setting up Zonemaster Backend with PostgreSQL on CentOS is not supported at this time.


#### Configuring PostgreSQL on Debian and Ubuntu

Connect to Postgres as a user with administrative privileges and set things up:

```sh
sudo -u postgres psql -f "$HOME/zonemaster-backend/docs/initial-postgres.sql"
```

This creates a database called `zonemaster`, as well as a user called "zonemaster" with the password "zonemaster" (as stated in the config file). This user has just enough permissions to run the backend software.


#### Configuring PostgreSQL on FreeBSD

Start the PostgreSQL server according to its instructions then initiate the database using the following script.

```sh
psql -U pgsql template1 -f docs/initial-postgres.sql
```


## Startup

### Starting services on CentOS

```sh
sudo systemctl start zm-centos
```


### Starting services on Debian and Ubuntu

Start the processes, point pid and log to a appropriate-for-your-OS location
(first line is the API, second is the test runner itself)

```sh
starman --error-log="$HOME/logs/backend_starman.log" --listen=127.0.0.1:5000 --pid="$HOME/logs/starman.pid" --daemonize /usr/local/bin/zonemaster_webbackend.psgi
```

Starting the starman part that listens for and answers the JSON::RPC requests 

```sh
sudo service zm-backend.sh start
```

This only needs to be run as root in order to make sure the log file can be
opened. The `starman` process will change to the `www-data` user as soon as it
can, and all of the real work will be done as that user.


### Starting services on FreeBSD

Start the processes, point pid and log to a appropriate-for-your-OS location
(first line is the API, second is the test runner itself)

```sh
starman --error-log="$HOME/logs/error.log" --pid-file="$HOME/logs/starman.pid" --listen=127.0.0.1:5000 --daemonize /usr/local/bin/zonemaster_webbackend.psgi
zm_wb_daemon start
```


## Post-installation sanity check

If you followed this instructions to the letter, you should
be able to use the API on localhost port 5000, like this:

```sh
curl -s -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"version_info","id":"1"}' http://localhost:5000/ && echo
```

The command is expected to give an immediate JSON response.


## What's next

Next step is to install the [Web UI](https://github.com/dotse/zonemaster-gui/blob/master/docs/installation.md) if you wish so.
You can also look into the [API documentation](API.md) to see how you can use the API for your use.


# Appendices

## Quick installation using a Docker container

Install the docker package on your OS

Follow the installation instructions for your OS -> https://docs.docker.com/engine/installation/linux/

Pull the docker image containing the complete Zonemaster distribution (GUI + Backend + Engine)

```sh
docker pull afniclabs/zonemaster-gui
```

Start the container in the background

```sh
docker run -t -p 50080:50080 afniclabs/zonemaster-gui 
```

Use the Zonemaster GUI by pointing your browser at

```sh
http://localhost:50080/
```

Use the Zonemaster engine from the command line

```sh
docker run -t -i afniclabs/zonemaster-gui bash
```


## Administrative tasks

### Performing administrative tasks for MySQL

If, at some point, you want to delete all traces of Zonemaster in the database, you can run the file `docs/cleanup-mysql.sql` as a database administrator.
It removes the user and drops the database (obviously taking all data with it).


### Performing administrative tasks on Debian and Ubuntu

If you would like to kill the starman process, you can issue this command:

```sh
kill `cat "$HOME/logs/starman.pid"`
```
