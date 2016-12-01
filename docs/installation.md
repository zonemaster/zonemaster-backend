# Zonemaster Backend installation guide

## Overview

Zonemaster *Backend* needs to run on an operating system. One can choose any of
the following OS to install the *Backend* after having the required
[Prerequisites](#prerequisites).

* [CentOS](#centos) 7 - 64 bits 
* [Debian](#debian) 8 (Jessie) - 64 bits 
* [Ubuntu](#debian)
* [FreeBSD](#freebsd) 

>
> Note: We assume the installation instructions will work for earlier OS
> versions too. If you have any issue in installing the Zonemaster engine with
> earlier versions, please send a mail with details to contact@zonemaster.net 
>

In addition, Zonemaster *Backend* needs a database engine. The choice for the database are
as follows :

* MySQL 
* PostgreSQL 9.3 or higher 
* SQLite 


## Prerequisites

This guide assumes that the following softwares are already installed on the
target system :

* the chosen operating system 
* sudo (only for installation and other administrative tasks) 
* cpanm (only for installation) 
* curl (only for post-installation sanity check)
* [Zonemaster Engine](https://github.com/dotse/zonemaster-engine/blob/master/docs/installation.md) is installed 

## CentOS 

### 3.1 Installing dependencies 

```sh 
sudo yum install perl-Module-Install perl-IO-CaptureOutput perl-String-ShellQuote 
sudo cpanm -i Config::IniFiles Daemon::Control JSON::RPC::Dispatch Parallel::ForkManager Plack::Builder Plack::Middleware::Debug Router::Simple::Declare Starman 
```

### 3.2 Install the chosen database engine and related dependencies.

#### 3.2.1 MySQL

```sh 
sudo yum install wget 
wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm 
sudo rpm -ivh mysql-community-release-el7-5.noarch.rpm 
sudo yum install mysql-server perl-DBD-mysql 
sudo systemctl start mysqld 
```

Verify that MySQL has started 
```sh
service mysqld status
```


#### 3.2.2 PostgreSQL

>
> At this time there is no instruction for using PostgreSQL on CentOS.
>

#### 3.2.3 SQLite

>
> At this time there is no instruction for using SQLite on CentOS.
>

### 3.3 Installation of the backend

```sh
sudo cpanm Zonemaster::WebBackend
```

### 3.4 Directory and file manipulation

```sh
sudo mkdir /etc/zonemaster
mkdir "$HOME/logs"
```

The Zonemaster::WebBackend module installs a number of configuration files in a
shared data directory.  This section refers to the shared data directory as the
current directory, so locate it and go there like this:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-WebBackend")'`
```

Copy the `backend_config.ini` file to `/etc/zonemaster`.

```sh
sudo cp ./backend_config.ini /etc/zonemaster/
```

### 3.5 Service script set up
Copy the example init file to the system directory.  You may wish to edit the
file in order to use a more suitable user and group.  As distributed, it uses
the MySQL user and group, since we can be sure that exists and it shouldn't mess
up anything included with the system.

```sh
sudo cp ./zm-centos.sh /etc/init.d/
sudo chmod +x /etc/init.d/zm-centos.sh
```
### 3.6 Chosen database configuration

#### 3.6.1 MySQL

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
number_of_processes_for_frontend_testing = 20
number_of_processes_for_batch_testing    = 20
```

Using a database adminstrator user (called root in the example below), run the
setup file:

```sh
mysql --user=root --password < ./initial-mysql.sql
```

This creates a database called `zonemaster`, as well as a user called
"zonemaster" with the password "zonemaster" (as stated in the config file). This
user has just enough permissions to run the backend software.

>
> Note : Only run the above command during an initial installation of the
> Zonemaster backend. If you do this on an existing system, you will wipe out the
> data in your database.
>

 
If, at some point, you want to delete all traces of Zonemaster in the database,
you can run the file `cleanup-mysql.sql` as a database administrator. Commands
for locating and running the file are below. It removes the user and drops the
database (obviously taking all data with it).
 

```sh
perl -MFile::ShareDir -le 'print File::ShareDir::dist_file("Zonemaster-WebBackend", "cleanup-mysql.sql")'
./cleanup-mysql.sql
```


#### 3.6.2 PostgreSQL

>
> At this time there is no instruction for creating a database in PostgreSQL.
>

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
number_of_processes_for_frontend_testing = 20
number_of_processes_for_batch_testing    = 20
```


#### 3.6.3 SQLite

>
> At this time there is no instruction for configuring/creating a database in PostgreSQL.
>

### 3.7 Service startup

```sh
sudo systemctl start zm-centos
```

### 3.8 Post-installation sanity check

If you followed this instructions to the letter, you should be able to use the
API on localhost port 5000, like this:

```sh
curl -s -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"version_info","id":"1"}' http://localhost:5000/ && echo
```

The command is expected to give an immediate JSON response similiar to :

```sh
{"id":140715758026879,"jsonrpc":"2.0","result":"Zonemaster Test Engine Version: v1.0.2"}
```
## Debian 

### Installing dependencies

```sh
sudo apt-get update
sudo apt-get install git libmodule-install-perl libconfig-inifiles-perl libdbd-sqlite3-perl starman libio-captureoutput-perl libproc-processtable-perl libstring-shellquote-perl librouter-simple-perl libclass-method-modifiers-perl libtext-microtemplate-perl libdaemon-control-perl
sudo cpanm -i  Test::Requires Plack::Middleware::Debug Parallel::ForkManager JSON::RPC
```
>
> Note: The Perl modules `Parallel::ForkManager` and `JSON::RPC` exist as Debian
> packages, but with versions too old to be useful for us.
>

### Install the chosen database engine and related dependencies

#### MySQL

```sh
sudo apt-get install mysql-server libdbd-mysql-perl
```

#### PostgreSQL

```sh
sudo apt-get install libdbd-pg-perl postgresql
```

#### SQLite

>
> At this time there is no instruction for using SQLite on Debian and Ubuntu.
>

### Installation of the backend

```sh
sudo cpanm Zonemaster::WebBackend
```
### Directory and file manipulation

```sh
sudo mkdir /etc/zonemaster
mkdir "$HOME/logs"
```

The Zonemaster::WebBackend module installs a number of configuration files in a
shared data directory.  This section refers to the shared data directory as the
current directory, so locate it and go there like this:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-WebBackend")'`
```

Copy the `backend_config.ini` file to `/etc/zonemaster`.

```sh
sudo cp ./backend_config.ini /etc/zonemaster/
```
### Service script set up

Copy the file `./zm-backend.sh` to the directory `/etc/init`, make it an
executable file, and add the file to start up script.

```sh
sudo cp ./zm-backend.sh /etc/init.d/
sudo chmod +x /etc/init.d/zm-backend.sh
sudo update-rc.d zm-backend.sh defaults
```

>
> At this time there is no instruction for running Zonemaster *Workers* as
> services on Debian and Ubuntu.
>

### Chosen database configuration

#### MySQL
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
number_of_processes_for_frontend_testing = 20
number_of_processes_for_batch_testing    = 20
```

Using a database adminstrator user (called root in the example below), run the
setup file:

```sh
mysql --user=root --password < ./initial-mysql.sql
```

This creates a database called `zonemaster`, as well as a user called
"zonemaster" with the password "zonemaster" (as stated in the config file). This
user has just enough permissions to run the backend software.

>
> Note : Only run the above command during an initial installation of the
> Zonemaster backend. If you do this on an existing system, you will wipe out
> the
> data in your database.
>

If, at some point, you want to delete all traces of Zonemaster in the database,
you can run the file `cleanup-mysql.sql` as a database administrator. Commands
for locating and running the file are below. It removes the user and drops the
database (obviously taking all data with it).


```sh
perl -MFile::ShareDir -le 'print File::ShareDir::dist_file("Zonemaster-WebBackend", "cleanup-mysql.sql")'
./cleanup-mysql.sql
```

#### PostgreSQL
Connect to Postgres as a user with administrative privileges and set things up:

```sh
sudo -u postgres psql -f ./initial-postgres.sql
```

This creates a database called `zonemaster`, as well as a user called
"zonemaster" with the password "zonemaster" (as stated in the config file). This
user has just enough permissions to run the backend software.

#### SQLite

>
> At this time there is no instruction for configuring and creating a database
> in SQLite.
>

### Service startup
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

### Post-installation sanity check

If you followed this instructions to the letter, you should be able to use the
API on localhost port 5000, like this:

```sh
curl -s -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"version_info","id":"1"}' http://localhost:5000/ && echo
```

The command is expected to give an immediate JSON response similiar to :

```sh
{"id":140715758026879,"jsonrpc":"2.0","result":"Zonemaster Test Engine Version: v1.0.2"}
```

## FreeBSD


 
