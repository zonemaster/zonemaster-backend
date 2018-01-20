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

### 1.1 Install Zonemaster::Backend and related dependencies (CentOS)

> **Note:** Zonemaster::LDNS and Zonemaster::Engine are not listed here as they
> are dealt with in the [prerequisites](#prerequisites) section.

Install dependencies available from binary packages:

```sh 
sudo yum install perl-Module-Install perl-IO-CaptureOutput perl-String-ShellQuote 
```

Install dependencies not available from binary packages:

```sh 
sudo cpan -i Config::IniFiles Daemon::Control JSON::RPC::Dispatch Parallel::ForkManager Plack::Builder Plack::Middleware::Debug Router::Simple::Declare Starman 
```

Install Zonemaster::Backend: 
```sh
sudo cpan -i Zonemaster::Backend
```
> The command above might try to install "DBD::Pg" and "DBD::mysql".
> You can ignore if it fails. The relevant libraries are installed further down in these instructions.

Add Zonemaster user:
```sh
sudo useradd -r -c "Zonemaster daemon user" zonemaster
```

### 1.2 Database engine installation and configuration (CentOS)

Check the [declaration of prerequisites] to make sure your preferred combination
of operating system version and database engine version is supported.


#### 1.2.1 Instructions for MySQL (CentOS)

Install files to their proper locations:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
sudo install -d /etc/zonemaster
sudo install --mode=755 ./backend_config.ini /etc/zonemaster/
sudo install --mode=755 ./zm-centos.sh /etc/init.d/
mkdir "$HOME/logs"
```

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/=MySQL/' /etc/zonemaster/backend_config.ini
```

Install, configure and start database engine (and Perl bindings):

```sh 
sudo rpm -ivh http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
sudo yum install mysql-server perl-DBD-mysql 
sudo systemctl start mysqld 
```

Verify that MySQL has started:

```sh
service mysqld status
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

#### 1.2.2 Instructions for PostgreSQL (CentOS)

Install files to their proper locations:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
sudo install -d /etc/zonemaster
sudo install --mode=755 ./backend_config.ini /etc/zonemaster/
sudo install --mode=755 ./zm-centos.sh /etc/init.d/
mkdir "$HOME/logs"
```

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/=PostgreSQL/' /etc/zonemaster/backend_config.ini
```

Add PostgreSQL package repository needed to get the appropriate PostgreSQL 
binary package

```sh
sudo rpm -iUvh https://yum.postgresql.org/9.3/redhat/rhel-7-x86_64/pgdg-centos93-9.3-3.noarch.rpm
```

Install the PostgreSQL packages:

```sh
sudo yum -y install postgresql93 postgresql93-server postgresql93-contrib postgresql93-libs postgresql93-devel perl-DBD-Pg
```

To enable PostgreSQL from boot:

```sh
sudo systemctl enable postgresql-9.3
```

Initialise PostgreSQL:

```sh
sudo /usr/pgsql-9.3/bin/postgresql93-setup initdb
```

Configure:

```sh
# In the below file modify all instances of "ident" to "md5"
sudoedit /var/lib/pgsql/9.3/data/pg_hba.conf
```

Start PostgreSQL:

```sh
sudo systemctl start postgresql-9.3 
```

Verify PostgreSQL has started:

```sh
sudo systemctl status postgresql-9.3
```

Initialize Zonemaster database:

```sh
sudo -u postgres psql -f ./initial-postgres.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user called
> "zonemaster" with the password "zonemaster" (as stated in the config file).
> This user has just enough permissions to run the backend software.


#### 1.2.3 Instructions for SQLite (CentOS)

>
> At this time there is no instruction for using SQLite on CentOS.
>

### 1.3 Service configuration and startup (CentOS)

Start the service:

```sh
sudo /etc/init.d/zm-centos.sh start
```

Check that the service has started:

```sh
sudo /etc/init.d/zm-centos.sh status
```

### 1.4 Post-installation sanity check (CentOS)

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

> **Note:** Zonemaster::LDNS and Zonemaster::Engine are not listed here as they
> are dealt with in the [prerequisites](#prerequisites) section.

Install dependencies available from binary packages:

```sh
sudo apt-get install libclass-method-modifiers-perl libconfig-inifiles-perl libdaemon-control-perl libdata-dump-perl libdbd-sqlite3-perl libdbi-perl libfile-sharedir-perl libfile-slurp-perl libhtml-parser-perl libintl-perl libio-captureoutput-perl libjson-pp-perl libmoose-perl libplack-perl librouter-simple-perl libstring-shellquote-perl libtest-requires-perl libtest-warn-perl libtext-microtemplate-perl libtie-simple-perl starman
```

Install dependencies not available from binary packages:

```sh
sudo cpan -i JSON::RPC Plack::Middleware::Debug Parallel::ForkManager Net::IP::XS
```

Install Zonemaster::Backend:

```sh
sudo cpan -i Zonemaster::Backend
```

> The command above might try to install "DBD::Pg" and "DBD::mysql".
> You can ignore if it fails. The relevant libraries are installed further down in these instructions.

### 2.2 Database engine installation and configuration (Debian)

Check the [declaration of prerequisites] to make sure your preferred combination
of operating system version and database engine version is supported.

#### 2.2.1 Instructions for MySQL (Debian)

Install files to their proper locations:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
sudo install -d /etc/zonemaster
sudo install --mode=755 ./backend_config.ini /etc/zonemaster/
sudo install --mode=755 ./zm-backend.sh /etc/init.d/
mkdir "$HOME/logs"
```

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/=MySQL/' /etc/zonemaster/backend_config.ini
```

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


#### 2.2.2 Instructions for PostgreSQL (Debian)

Install files to their proper locations:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
sudo install -d /etc/zonemaster
sudo install --mode=755 ./backend_config.ini /etc/zonemaster/
sudo install --mode=755 ./zm-backend.sh /etc/init.d/
mkdir "$HOME/logs"
```

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/=PostgreSQL/' /etc/zonemaster/backend_config.ini
```

The following block of commands is for **Debian 7** only. For all others, go to the step of installing
database engine. First create or edit Debian 7 sources list file. Then fetch and import the repository signing key.
And finally update the package lists.

```sh
echo -e "\ndeb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main" | sudo tee -a /etc/apt/sources.list.d/pgdg.list
wget -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
```

For all versions of Debian and Ubuntu, install, configure and start database engine (and Perl bindings):

```sh
sudo apt-get install libdbd-pg-perl postgresql
```

Check that you have a PostgreSQL installation 9.2 or later. The version should also match the supported database
engine version depending on OS found in [Zonemaster/README](https://github.com/dotse/zonemaster/blob/master/README.md).

```sh
psql --version
```

Initialize the database:

```sh
sudo -u postgres psql -f ./initial-postgres.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user called
> "zonemaster" with the password "zonemaster" (as stated in the config file).
> This user has just enough permissions to run the backend software.


#### 2.2.3 Instructions for SQLite (Debian)

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

For all commands below, acquire privileges, i.e. become root:

```sh
su -l
```

### 3.1 Install Zonemaster::Backend and related dependencies (FreeBSD)

> **Note:** Zonemaster::LDNS and Zonemaster::Engine are not listed here as they
> are dealt with in the [prerequisites](#prerequisites) section.

Install dependencies available from binary packages:

```sh
pkg install p5-Config-IniFiles p5-Daemon-Control p5-DBI p5-File-ShareDir p5-File-Slurp p5-HTML-Parser p5-IO-CaptureOutput p5-JSON-PP p5-JSON-RPC p5-Locale-libintl p5-Moose p5-Parallel-ForkManager p5-Plack p5-Plack-Middleware-Debug p5-Router-Simple p5-Starman p5-String-ShellQuote
```

Install dependencies not available from binary packages:

```sh
cpan -i Net::IP::XS
```

Install Zonemaster::Backend:

```sh
cpan -i Zonemaster::Backend
```

> The command above might try to install "DBD::Pg" and "DBD::mysql".
> You can ignore if it fails. The relevant libraries are installed further down in these instructions.

Add `zonemaster` user and group:
```sh
pw groupadd zonemaster
pw useradd zonemaster -g zonemaster -s /sbin/nologin -d /nonexistent -c "Zonemaster daemon user"
```

### 3.2 Database engine installation and configuration (FreeBSD)

Check the [declaration of prerequisites] to make sure your preferred combination
of operating system version and database engine version is supported.

#### 3.2.1 Instructions for MySQL (FreeBSD)

Install files to their proper locations:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
install -d /etc/zonemaster
install -m 644 ./backend_config.ini /etc/zonemaster/
```

Configure Zonemaster::Backend to use the correct database engine:

```sh
sed -i '/\bengine\b/ s/=.*/=MySQL/' /usr/local/etc/zonemaster/backend_config.ini
```

Install, configure and start database engine (and Perl bindings):

```sh
pkg install mysql56-server p5-DBD-mysql
echo 'mysql_enable="YES"' | tee -a /etc/rc.conf
service mysql-server start
```

Initialize the database:

```sh
mysql < ./initial-mysql.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user
> called "zonemaster" with the password "zonemaster" (as stated in the config
> file). This user has just enough permissions to run the backend software.
>
> Only run this command during an initial installation of the Zonemaster
> backend. If you do this on an existing system, you will wipe out the data in
> your database.


#### 3.2.2 Instructions for PostgreSQL (FreeBSD)

Install files to their proper locations:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
install -d /etc/zonemaster
install -m 644 ./backend_config.ini /etc/zonemaster/
```

Configure Zonemaster::Backend to use the correct database engine:

```sh
sed -i '/\bengine\b/ s/=.*/=PostgreSQL/' /usr/local/etc/zonemaster/backend_config.ini
```

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

#### 3.2.3 Instructions for SQLite (FreeBSD)

>
> At this time there is no instruction for configuring and creating a database
> in SQLite.
>

### 3.3 Service startup (FreeBSD)

Install service scripts:

```sh
install -m 775 -g zonemaster -d /var/log/zonemaster
install -m 775 -g zonemaster -d /var/run/zonemaster
install -m 755 ./zm_rpcapi-bsd /usr/local/etc/rc.d/zm_rpcapi
install -m 755 ./zm_testagent-bsd /usr/local/etc/rc.d/zm_testagent
echo 'zm_rpcapi_enable="YES"' | tee -a /etc/rc.conf
echo 'zm_testagent_enable="YES"' | tee -a /etc/rc.conf
```

Start services:

```sh
service zm_rpcapi start
service zm_testagent start
```

### 3.4 Post-installation sanity check (FreeBSD)

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


## Cleaning up the database

If, at some point, you want to delete all traces of Zonemaster in the database,
you can run the file `cleanup-mysql.sql` or file `cleanup-postgres.sql`
as a database administrator. Commands
for locating and running the file are below. It removes the user and drops the
database (obviously taking all data with it).

### MySQL

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
mysql --user=root --password < ./cleanup-mysql.sql
```

### PostgreSQL

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
sudo -u postgres psql -f ./cleanup-postgres.sql # MUST BE VERIFIED!
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
