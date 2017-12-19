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

This instruction covers the following operating systems:

 * [CentOS](#1-installation-on-centos)
 * [Debian](#2-installation-on-debian)
 * [FreeBSD](#3-installation-on-freebsd)
 * [Ubuntu](#4-installation-on-ubuntu)


## 1. Installation on CentOS

### 1.1 Installing dependencies (CentOS)

```sh 
sudo yum install perl-Module-Install perl-IO-CaptureOutput perl-String-ShellQuote 
sudo cpan -i Config::IniFiles Daemon::Control JSON::RPC::Dispatch Parallel::ForkManager Plack::Builder Plack::Middleware::Debug Router::Simple::Declare Starman 
```

### 1.2 Install the chosen database engine and related dependencies (CentOS)

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
> [Sandoche! I think we should be able to support PostgreSQL!
> Can you try to find PostgreSQL package plus perl lib?]
>

#### 1.2.3 SQLite

>
> At this time there is no instruction for using SQLite on CentOS.
>

### 1.3 Installation of Zonemaster Backend (CentOS)

```sh
sudo cpan -i Zonemaster::Backend
```

### 1.4 Directory and file manipulation (CentOS)

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

If you have selected **MySQL**, copy the Backend configuration file with the 
following command:

```sh
sudo cp ./backend_config.ini-mysql /etc/zonemaster/backend_config.ini
```

If you have selected **PostgreSQL**, copy the Backend configuration file with the 
following command:

```sh
sudo cp ./backend_config.ini-postgresql /etc/zonemaster/backend_config.ini
```

### 1.5 Service script set up (CentOS)
Copy the example init file to the system directory.  You may wish to edit the
file in order to use a more suitable user and group.  As distributed, it uses
the MySQL user and group, since we can be sure that exists and it shouldn't mess
up anything included with the system.

If you have selected **MySQL**, copy and activate the Backend start file with the 
following command:

```sh
sudo cp ./zm-centos.sh-mysql /etc/init.d/zm-centos.sh
sudo chmod +x /etc/init.d/zm-centos.sh
```

If you have selected **PostgreSQL**, copy and activate the Backend start file with the 
following command:

```sh
sudo cp ./zm-centos.sh-postgresql /etc/init.d/zm-centos.sh
sudo chmod +x /etc/init.d/zm-centos.sh
```


### 1.6 Chosen database configuration (CentOS)

#### 1.6.1 MySQL

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

Initialize the database:

```sh
sudo -u postgres psql -f ./initial-postgres.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user called
> "zonemaster" with the password "zonemaster" (as stated in the config file).
> This user has just enough permissions to run the backend software.

#### 1.6.3 SQLite

>
> At this time there is no instruction for configuring/creating a database in PostgreSQL.
>

### 1.7 Service startup (CentOS)

```sh
sudo /etc/init.d/zm-centos.sh start
```

### 1.8 Post-installation sanity check (CentOS)

If you followed this instructions to the letter, you should be able to use the
API on localhost port 5000, like this:

```sh
curl -s -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"version_info","id":"1"}' http://localhost:5000/ && echo
```

The command is expected to give an immediate JSON response similiar to :

```json
{ "jsonrpc": "2.0", "id": 1, "result": { "zonemaster_backend": "1.0.7", "zonemaster_engine": "v1.0.14" } }
```


## 2. Installation on Debian

### 2.1 Install Zonemaster::Backend and related dependencies (Debian)

Install dependencies available from binary packages:

```sh
sudo apt-get install libclass-method-modifiers-perl libconfig-inifiles-perl libdaemon-control-perl libdata-dump-perl libdbd-sqlite3-perl libdbi-perl libfile-sharedir-perl libfile-slurp-perl libhtml-parser-perl libintl-perl libio-captureoutput-perl libjson-pp-perl libjson-rpc-perl libmodule-build-tiny-perl libmoose-perl libplack-perl librouter-simple-perl libstring-shellquote-perl libtest-requires-perl libtest-warn-perl libtext-microtemplate-perl libtie-simple-perl starman
```

Install dependencies not available from binary packages:

```sh
sudo cpan -i Plack::Middleware::Debug Parallel::ForkManager Net::IP::XS
```

> **Note:** Zonemaster::LDNS and Zonemaster::Engine are not listed here as they
> are dealt with in the [prerequisites](#prerequisites) section.

Install Zonemaster::Backend:

```sh
sudo cpan -i Zonemaster::Backend
```

If you have selected **MySQL**, install files to their proper locations:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
sudo install -d /etc/zonemaster
sudo install --mode=755 ./backend_config.ini-mysql /etc/zonemaster/backend_config.ini
sudo install --mode=755 ./zm-backend.sh-mysql /etc/init.d/zm-backend.sh
mkdir "$HOME/logs"
```

If you have selected **PostgreSQL**, install files to their proper locations:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
sudo install -d /etc/zonemaster
sudo install --mode=755 ./backend_config.ini-postgresql /etc/zonemaster/backend_config.ini
sudo install --mode=755 ./zm-backend.sh-postgresql /etc/init.d/zm-backend.sh
mkdir "$HOME/logs"
```


### 2.2 Database engine installation and configuration (Debian)

Check the [declaration of prerequisites] to make sure your preferred combination
of operating system version and database engine version is supported.

#### 2.2.1 Instructions for **MySQL**:

Install the database engine and its dependencies:

```sh
sudo apt-get install mysql-server libdbd-mysql-perl
```

Initialize the database:

```sh
mysql --user=root --password < ./initial-mysql.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user
> called "zonemaster" with the password "zonemaster" (as stated in the config
> file). This user has just enough permissions to run the backend software.
>
> Only run this command during an initial installation of the Zonemaster
> backend. If you do this on an existing system, you will wipe out the data in
> your database.


#### 2.2.2 Instructions for **PostgreSQL**:

Install, configure and start database engine (and Perl bindings):

```sh
sudo apt-get install libdbd-pg-perl postgresql
```

Initialize the database:

```sh
sudo -u postgres psql -f ./initial-postgres.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user called
> "zonemaster" with the password "zonemaster" (as stated in the config file).
> This user has just enough permissions to run the backend software.


#### 2.2.3 SQLite

>
> At this time there is no instruction for configuring/creating a database in SQLite 
>


### 2.3 Service configuration and startup (Debian)

Add `zm-backend.sh` to start up script:

```sh
sudo update-rc.d zm-backend.sh defaults
```

Start the service:

```sh
sudo service zm-backend.sh start
```

Check that the service has started:

```sh
sudo service zm-backend.sh status
```

### 2.4 Post-installation sanity check (Debian)

If you followed this instructions to the letter, you should be able to use the
API on localhost port 5000, like this:

```sh
curl -s -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"version_info","id":"1"}' http://localhost:5000/ && echo
```

The command is expected to give an immediate JSON response similiar to:

```json
{ "jsonrpc": "2.0", "id": 1, "result": { "zonemaster_backend": "1.0.7", "zonemaster_engine": "v1.0.14" } }
```


## 3. Installation on FreeBSD

### 3.1 Acquire privileges (FreeBSD)

Become root:

```sh
su -l
```


### 3.2 Install Zonemaster::Backend and related dependencies (FreeBSD)

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


### 3.3 Service configuration (FreeBSD)

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

If you have selected **MySQL**, copy the Backend configuration file with the 
following command:

```sh
sudo cp ./backend_config.ini-mysql /etc/zonemaster/backend_config.ini
```

If you have selected **PostgreSQL**, copy the Backend configuration file with the 
following command:

```sh
sudo cp ./backend_config.ini-postgresql /etc/zonemaster/backend_config.ini
```

>
> At this time there is no instruction for running Zonemaster Web backends
> nor Workers as services on FreeBSD.
>


### 3.4 Database engine installation and configuration (FreeBSD)

Zonemaster::Backend supports MySQL and PostgreSQL on FreeBSD. See [declaration
of prerequisites] for details on specific versions.

#### 3.4.1 Instructions for **MySQL**:

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

#### 3.4.2 Instructions for **PostgreSQL**:

Install, configure and start database engine (and Perl bindings):

```sh
pkg install postgresql95-server p5-DBD-Pg
echo 'postgresql_enable="YES"' | tee -a /etc/rc.conf
service postgresql initdb
service postgresql start
```

> **ToDo:** Add instruction about the
> `config_logfilter_1=/full/path/to/a/config_file.json` line.

Initialize the database:

```sh
psql -U pgsql -f ./initial-postgres.sql template1
```

#### 3.4.3 Instructions for **SQLite**:

>
> At this time there is no instruction for configuring and creating a database
> in SQLite.
>

### 3.5 Service startup (FreeBSD)

```sh
starman --error-log="$HOME/logs/error.log" --pid-file="$HOME/logs/starman.pid" --listen=127.0.0.1:5000 --daemonize /usr/local/bin/zonemaster_backend_rpcapi.psgi 
zonemaster_backend_testagent start
```

### 3.6 Post-installation sanity check (FreeBSD)

If you followed this instructions to the letter, you should be able to use the
API on localhost port 5000, like this:

```sh
curl -s -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"version_info","id":"1"}' http://localhost:5000/ && echo
```

The command is expected to give an immediate JSON response similiar to :

```json
{ "jsonrpc": "2.0", "id": 1, "result": { "zonemaster_backend": "1.0.7", "zonemaster_engine": "v1.0.14" } }
```


## 4. Installation on Ubuntu

Use the procedure for installation on [Debian](#2-installation-on-debian).


## What to do next?

* For a web interface, follow the [Zonemaster::GUI installation] instructions.
* For a command line interface, follow the [Zonemaster::CLI installation] instruction.
* For a JSON-RPC API, see the Zonemaster::Backend [JSON-RPC API] documentation.


### Cleaning up MySQL

If, at some point, you want to delete all traces of Zonemaster in the database,
you can run the file `cleanup-mysql.sql` as a database administrator. Commands
for locating and running the file are below. It removes the user and drops the
database (obviously taking all data with it).

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
mysql --user=root --password < ./cleanup-mysql.sql
```


-------

[Declaration of prerequisites]: https://github.com/dotse/zonemaster#prerequisites
[JSON-RPC API]: API.md
[Main Zonemaster repository]: https://github.com/dotse/zonemaster/blob/master/README.md
[Zonemaster::CLI installation]: https://github.com/dotse/zonemaster-cli/blob/master/docs/Installation.md
[Zonemaster::GUI installation]: https://github.com/dotse/zonemaster-gui/blob/master/docs/Installation.md
[Zonemaster::Engine installation]: https://github.com/dotse/zonemaster-engine/blob/master/docs/Installation.md
[Zonemaster::Engine]: https://github.com/dotse/zonemaster-engine/blob/master/README.md
[Zonemaster::LDNS]: https://github.com/dotse/zonemaster-ldns/blob/master/README.md

Copyright (c) 2013 - 2017, IIS (The Internet Foundation in Sweden) \
Copyright (c) 2013 - 2017, AFNIC \
Creative Commons Attribution 4.0 International License

You should have received a copy of the license along with this
work.  If not, see <https://creativecommons.org/licenses/by/4.0/>.
