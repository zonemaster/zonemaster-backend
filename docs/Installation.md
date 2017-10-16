# Installation

## Overview

This document describes prerequisites, installation, configuration, startup and
post-install sanity checking for Zonemaster::Backend. The final section wraps up
with a few pointer to interfaces for Zonemaster::Backend. For an overview of the
Zonemaster product, please see the [main Zonemaster Repository].


## Prerequisites

Before installing Zonemaster::Backend, you should [install Zonemaster::Engine][
Zonemaster::Engine installation].

> **Note:** [Zonemaster::Engine] and [Zonemaster::LDNS] are dependencies of
> Zonemaster::Backend. Zonemaster::LDNS has a special installation requirement,
> and Zonemaster::Engine has a list of dependencies that you may prefer to
> install from your operating system distribution (rather than CPAN).
> We recommend following the Zonemaster::Engine installation instruction.

For details on supported versions of Perl, database engine and operating system
for Zonemaster::Backend, see the [declaration of prerequisites].

> **Note:** In addition to the normal dependencies, the post-installation sanity
> check instruction assumes that you have curl installed.


## Installation

This instruction covers the following operating systems:

 * [CentOS](#1-centos)
 * [Debian](#2-debian)
 * [FreeBSD](#3-freebsd)
 * [Ubuntu](#4-ubuntu)


## 1. CentOS

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

Verify that MySQL has started:

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


## 2. Debian

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


## 3. FreeBSD

### 3.1 Acquire privileges

Become root:

```sh
su
```


### 3.2 Install Zonemaster::Backend and related dependencies

Install dependencies available from binary packages:

```sh
pkg install p5-Config-IniFiles p5-Daemon-Control p5-DBI p5-File-ShareDir p5-File-Slurp p5-HTML-Parser p5-IO-CaptureOutput p5-JSON-PP p5-JSON-RPC p5-Locale-libintl p5-Moose p5-Parallel-ForkManager p5-Plack p5-Plack-Middleware-Debug p5-Router-Simple p5-Starman p5-String-ShellQuote
```

Install dependencies not available from binary packages:

```sh
cpan -i Net::IP::XS
```

> **Note:** Zonemaster::LDNS and Zonemaster::Engine are not listed here as they
> are dealt with in the [prerequisites](#prerequisites) section.

Install Zonemaster::Backend:

```sh
cpan -i Zonemaster::Backend
```


### 3.3 Service configuration

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

Copy the `backend_config.ini` file to `/etc/zonemaster`:

```sh
cp ./backend_config.ini /etc/zonemaster/
```

>
> At this time there is no instruction for running Zonemaster Web backends
> nor Workers as services on FreeBSD.
>


### 3.4 Database engine installation and configuratoin

Zonemaster::Backend supports MySQL and PostgreSQL on FreeBSD. See [declaration
of prerequisites] for details on specific versions.

 * Instructions for **MySQL**:

   Install the database engine and its dependencies:

   ```sh
   pkg install mysql56-server p5-DBD-mysql
   ```

   >
   > At this time there is no instruction for configuring/starting MySQL on FreeBSD.
   >

   Configure the database engine:

   >
   > At this time there is no instruction for configuring and creating a database
   > in MySQL.
   >

 * Instructions for **PostgreSQL**:

   Install, configure and start database engine (and Perl bindings):

   ```sh
   pkg install postgresql95-server p5-DBD-Pg
   echo 'postgresql_enable="YES"' | tee -a /etc/rc.conf
   service postgresql initdb
   service postgresql start
   ```

   Configure Zonemaster::Backend:

   Edit the file `/etc/zonemaster/backend_config.ini`.

   ```ini
   [DB]
   engine           = PostgreSQL
   user             = zonemaster
   password         = zonemaster
   database_host    = localhost
   database_name    = zonemaster
   polling_interval = 0.5

   [LOG]
   log_dir          = logs/

   [PERL]
   interpreter      = perl

   [ZONEMASTER]
   max_zonemaster_execution_time            = 300
   number_of_processes_for_frontend_testing = 20
   number_of_processes_for_batch_testing    = 20
   ```

   > **ToDo:** Add instruction about the
   > `config_logfilter_1=/full/path/to/a/config_file.json` line.

   Initialize the database:

   ```sh
   psql -U pgsql -f ./initial-postgres.sql template1
   ```

 * Instructions for **SQLite**:

   >
   > At this time there is no instruction for configuring and creating a database
   > in SQLite.
   >

### 3.5 Service startup

```sh
starman --error-log="$HOME/logs/error.log" --pid-file="$HOME/logs/starman.pid" --listen=127.0.0.1:5000 --daemonize /usr/local/bin/zonemaster_backend_rpcapi.psgi 
zonemaster_backend_testagent start
```

### 3.6 Post-installation sanity check

If you followed this instructions to the letter, you should be able to use the
API on localhost port 5000, like this:

```sh
curl -s -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"version_info","id":"1"}' http://localhost:5000/ && echo
```

The command is expected to give an immediate JSON response similiar to :

```json
{ "jsonrpc": "2.0", "id": 1, "result": { "zonemaster_backend": "1.0.7", "zonemaster_engine": "v1.0.14" } }
```


## 4. Ubuntu

Use the procedure for installation on [Debian](#2-debian).


## What to do next?

 * For a web interface, follow the [Zonemaster::GUI installation] instructions.
 * For a JSON-RPC API, see the Zonemaster::Backend [JSON-RPC API] documentation.


-------

[Declaration of prerequisites]: https://github.com/dotse/zonemaster#prerequisites
[JSON-RPC API]: API.md
[Main Zonemaster repository]: https://github.com/dotse/zonemaster
[Zonemaster::Engine installation]: https://github.com/dotse/zonemaster-engine/blob/master/docs/Installation.md
[Zonemaster::Engine]: https://github.com/dotse/zonemaster-engine
[Zonemaster::GUI installation]: https://github.com/dotse/zonemaster-gui/blob/master/docs/installation.md
[Zonemaster::LDNS]: https://github.com/dotse/zonemaster-ldns

Copyright (c) 2013 - 2017, IIS (The Internet Foundation in Sweden) \
Copyright (c) 2013 - 2017, AFNIC \
Creative Commons Attribution 4.0 International License

You should have received a copy of the license along with this
work.  If not, see <http://creativecommons.org/licenses/by/4.0/>.
