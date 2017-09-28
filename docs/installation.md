# Zonemaster Backend installation guide

## Overview

Zonemaster *Backend* needs to run on an operating system. One can choose any of
the following OS to install the *Backend* after having the required
[Prerequisites](#prerequisites).

* <a href="#centos">CentOS 7</a>  
* <a href="#debian">Debian 8 (Jessie)</a>  
* <a href="#debian">Ubuntu 16.04</a>  
* <a href="#freebsd">FreeBSD 10.3</a>  

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
* curl (only for post-installation sanity check)
* [Zonemaster Engine](https://github.com/dotse/zonemaster-engine/blob/master/docs/installation.md) is installed 

## <a name="centos"></a>1. CentOS 

### 1.1 Installing dependencies 

```sh 
sudo yum install perl-Module-Install perl-IO-CaptureOutput perl-String-ShellQuote 
sudo cpan -i Config::IniFiles Daemon::Control JSON::RPC::Dispatch Parallel::ForkManager Plack::Builder Plack::Middleware::Debug Router::Simple::Declare Starman 
```

### 1.2 Install the chosen database engine and related dependencies.

#### 1.2.1 MySQL

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

#### 1.2.2 PostgreSQL

>
> At this time there is no instruction for using PostgreSQL on CentOS.
>

#### 1.2.3 SQLite

>
> At this time there is no instruction for using SQLite on CentOS.
>

### 1.3 Installation of Zonemaster Backend

```sh
sudo cpan -i Zonemaster::Backend
```

### 1.4 Directory and file manipulation

```sh
sudo mkdir /etc/zonemaster
mkdir "$HOME/logs"
```

The Zonemaster::Backend module installs a number of configuration files in a
shared data directory.  This section refers to the shared data directory as the
current directory, so locate it and go there like this:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
```

Copy the `backend_config.ini` file to `/etc/zonemaster`.

```sh
sudo cp ./backend_config.ini /etc/zonemaster/
```

### 1.5 Service script set up
Copy the example init file to the system directory.  You may wish to edit the
file in order to use a more suitable user and group.  As distributed, it uses
the MySQL user and group, since we can be sure that exists and it shouldn't mess
up anything included with the system.

```sh
sudo cp ./zm-centos.sh /etc/init.d/
sudo chmod +x /etc/init.d/zm-centos.sh
```
### 1.6 Chosen database configuration

#### 1.6.1 MySQL

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
> Note : Only run the above command during an initial installation of
> Zonemaster Backend. If you do this on an existing system, you will wipe out the
> data in your database.
>

 
If, at some point, you want to delete all traces of Zonemaster in the database,
you can run the file `cleanup-mysql.sql` as a database administrator. Commands
for locating and running the file are below. It removes the user and drops the
database (obviously taking all data with it).
 

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
mysql --user=root --password < ./cleanup-mysql.sql
```


#### 1.6.2 PostgreSQL

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


#### 1.6.3 SQLite

>
> At this time there is no instruction for configuring/creating a database in PostgreSQL.
>

### 1.7 Service startup

```sh
sudo systemctl start zm-centos
```

### 1.8 Post-installation sanity check

If you followed this instructions to the letter, you should be able to use the
API on localhost port 5000, like this:

```sh
curl -s -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"version_info","id":"1"}' http://localhost:5000/ && echo
```

The command is expected to give an immediate JSON response similiar to :

```sh
{"id":140715758026879,"jsonrpc":"2.0","result":"Zonemaster Test Engine Version: v1.0.2"}
```

## <a name="debian"></a>2. Ubuntu & Debian 

### 2.1 Installing dependencies

```sh
sudo apt-get update
sudo apt-get install git libmodule-install-perl libconfig-inifiles-perl libdbd-sqlite3-perl starman libio-captureoutput-perl libproc-processtable-perl libstring-shellquote-perl librouter-simple-perl libclass-method-modifiers-perl libtext-microtemplate-perl libdaemon-control-perl
sudo cpan -i  Test::Requires Plack::Middleware::Debug Parallel::ForkManager JSON::RPC 
```
>
> Note: The Perl modules `Parallel::ForkManager` and `JSON::RPC` exist as Debian
> packages, but with versions too old to be useful for us.
>

### 2.2 Install the chosen database engine and related dependencies

#### 2.2.1 MySQL

```sh
sudo apt-get install mysql-server libdbd-mysql-perl
```

#### 2.2.2 PostgreSQL

```sh
sudo apt-get install libdbd-pg-perl postgresql
```

#### 2.2.3 SQLite

>
> At this time there is no instruction for using SQLite on Debian and Ubuntu.
>

### 2.3 Installation of Zonemaster Backend

```sh
sudo cpan -i Zonemaster::Backend
```
### 2.4 Directory and file manipulation

```sh
sudo mkdir /etc/zonemaster
mkdir "$HOME/logs"
```

The Zonemaster::Backend module installs a number of configuration files in a
shared data directory.  This section refers to the shared data directory as the
current directory, so locate it and go there like this:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
```

Copy the `backend_config.ini` file to `/etc/zonemaster`.

```sh
sudo cp ./backend_config.ini /etc/zonemaster/
```
### 2.5 Service script set up

Copy the file `./zm-backend.sh` to the directory `/etc/init`, make it an
executable file, and add the file to start up script.

```sh
sudo cp ./zm-backend.sh /etc/init.d/
sudo chmod +x /etc/init.d/zm-backend.sh
sudo update-rc.d zm-backend.sh defaults
```

### 2.6 Chosen database configuration

#### 2.6.1 MySQL

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
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
mysql --user=root --password < ./cleanup-mysql.sql
```

#### 2.6.2 PostgreSQL

Edit the file `/etc/zonemaster/backend_config.ini`.

```sh
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

Connect to Postgres as a user with administrative privileges and set things up:

```sh
sudo -u postgres psql -f ./initial-postgres.sql
```

This creates a database called `zonemaster`, as well as a user called
"zonemaster" with the password "zonemaster" (as stated in the config file). This
user has just enough permissions to run the backend software.

#### 2.6.3 SQLite

>
> At this time there is no instruction for configuring and creating a database
> in SQLite.
>

### 2.7 Service startup

Starting the starman part that listens for and answers the JSON::RPC requests

```sh
sudo service zm-backend.sh start
```

This only needs to be run as root in order to make sure the log file can be
opened. The `starman` process will change to the `www-data` user as soon as it
can, and all of the real work will be done as that user.

Check that the service has started 

```sh
sudo service zm-backend.sh status
```

### 2.8 Post-installation sanity check

If you followed this instructions to the letter, you should be able to use the
API on localhost port 5000, like this:

```sh
curl -s -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"version_info","id":"1"}' http://localhost:5000/ && echo
```

The command is expected to give an immediate JSON response similiar to :

```sh
{ "jsonrpc": "2.0", "id": 1, "result": { "zonemaster_backend": "1.0.7", "zonemaster_engine": "v1.0.14" } }
```

## <a name="freebsd"></a>3. FreeBSD

### 3.1 Become superuser
To do most of the following steps you have to be superuser (root). Change to
root and then execute the steps for FreeBSD.

su

### 3.2 Installing dependencies

```sh
pkg install p5-Config-IniFiles p5-DBI p5-File-Slurp p5-HTML-Parser p5-IO-CaptureOutput p5-JSON p5-JSON-RPC p5-Locale-libintl p5-libwww p5-Moose p5-Plack p5-Router-Simple p5-String-ShellQuote p5-Starman p5-File-ShareDir p5-Parallel-ForkManager p5-Daemon-Control p5-Module-Install p5-DBD-SQLite p5-Plack-Middleware-Debug
``` 

### 3.3 Install the chosen database engine and related dependencies

#### 3.3.1 MySQL

```sh
pkg install mysql56-server p5-DBD-mysql
```
>
> At this time there is no instruction for configuring/starting MySQL on FreeBSD.
>

#### 3.3.2 PostgreSQL

```sh
pkg install postgresql93-server p5-DBD-Pg
echo 'postgresql_enable="YES"' | sudo tee -a /etc/rc.conf
service postgresql initdb
service postgresql start
```

#### 3.3.3 SQLite

>
> At this time there is no instruction for using SQLite on FreeBSD.
>

### 3.4 Installation of the backend

```sh
cpan -i Zonemaster::Backend
```

### 3.5 Directory and file manipulation

```sh
mkdir /etc/zonemaster
mkdir "$HOME/logs"
```

The Zonemaster::Backend module installs a number of configuration files in a
shared data directory.  This section refers to the shared data directory as the
current directory, so locate it and go there like this:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
```

Copy the `backend_config.ini` file to `/etc/zonemaster`.

```sh
cp ./backend_config.ini /etc/zonemaster/
```

### 3.6 Service script set up

>
> At this time there is no instruction for running Zonemaster Web backends
> nor Workers as services on FreeBSD.
>

### 3.7 Chosen database configuration

#### 3.7.1 MySQL

>
> At this time there is no instruction for configuring and creating a database
> in SQLite.
>

#### 3.7.2 PostgreSQL

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

Start the PostgreSQL server according to its instructions then initiate the
database using the following script.

```sh
psql -U pgsql -f ./initial-postgres.sql template1
```

#### 3.7.3 SQLite

>
> At this time there is no instruction for configuring and creating a database
> in SQLite.
>

### 3.8 Service startup

```sh
starman --error-log="$HOME/logs/error.log" --pid-file="$HOME/logs/starman.pid" --listen=127.0.0.1:5000 --daemonize /usr/local/bin/zonemaster_backend_rpcapi.psgi 
zonemaster_backend_testagent start
```

### 3.9 Post-installation sanity check

If you followed this instructions to the letter, you should be able to use the
API on localhost port 5000, like this:

```sh
curl -s -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"version_info","id":"1"}' http://localhost:5000/ && echo
```

The command is expected to give an immediate JSON response similiar to :

```sh
{ "jsonrpc": "2.0", "id": 1, "result": { "zonemaster_backend": "1.0.7", "zonemaster_engine": "v1.0.14" } }
```

## What to do next?
>
> You will have to install the GUI or look at the API documentation. We will be
> updating this document with links on how to do that. 
>

-------

Copyright (c) 2013 - 2016, IIS (The Internet Foundation in Sweden)  
Copyright (c) 2013 - 2016, AFNIC  
Creative Commons Attribution 4.0 International License

You should have received a copy of the license along with this
work.  If not, see <http://creativecommons.org/licenses/by/4.0/>.
