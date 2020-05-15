# Installation

**Table of contents**

* [1. Overview](#1-overview)
* [2. Prerequisites](#2-prerequisites)
* [3. Installation on CentOS](#3-installation-on-centos)
  * [3.1 Install Zonemaster::Backend and related dependencies (CentOS)](#31-install-zonemasterbackend-and-related-dependencies-centos)
  * [3.2 Database engine installation and configuration (CentOS)](#32-database-engine-installation-and-configuration-centos)
  * [3.3 Service configuration and startup (CentOS)](#33-service-configuration-and-startup-centos)
  * [3.4 Post-installation (CentOS)](#34-post-installation-centos)
* [4. Installation on Debian](#4-installation-on-debian)
  * [4.1 Install Zonemaster::Backend and related dependencies (Debian)](#41-install-zonemasterbackend-and-related-dependencies-debian)
  * [4.2 Database engine installation and configuration (Debian)](#42-database-engine-installation-and-configuration-debian)
  * [4.3 Service configuration and startup (Debian)](#43-service-configuration-and-startup-debian)
  * [4.4 Post-installation (Debian)](#44-post-installation-debian)
* [5. Installation on FreeBSD](#5-installation-on-freebsd)
  * [5.1 Install Zonemaster::Backend and related dependencies (FreeBSD)](#51-install-zonemasterbackend-and-related-dependencies-freebsd)
  * [5.2 Database engine installation and configuration (FreeBSD)](#52-database-engine-installation-and-configuration-freebsd)
  * [5.3 Service startup (FreeBSD)](#53-service-startup-freebsd)
  * [5.4 Post-installation (FreeBSD)](#54-post-installation-freebsd)
* [6. Installation on Ubuntu](#6-installation-on-ubuntu)
* [7. Post-installation](#7-post-installation)
  * [7.1 Smoke test](#71-smoke-test)
  * [7.2 What to do next?](#72-what-to-do-next)
  * [7.3 Cleaning up the database](#73-cleaning-up-the-database)
  * [7.4 Upgrade Zonemaster database](#74-upgrade-zonemaster-database)

## 1. Overview

This document contains all steps needed to install Zonemaster::Backend. For an overview of the
Zonemaster product, please see the [main Zonemaster Repository].


## 2. Prerequisites

Before installing Zonemaster::Backend, you should [install Zonemaster::Engine][
Zonemaster::Engine installation].

> **Note:** [Zonemaster::Engine] and [Zonemaster::LDNS] are dependencies of
> Zonemaster::Backend. Zonemaster::LDNS has a special installation requirement,
> and Zonemaster::Engine has a list of dependencies that you may prefer to
> install from your operating system distribution (rather than CPAN).
> We recommend following the Zonemaster::Engine installation instruction.

Prerequisite for FreeBSD is that the package system is upadated and activated
(see the FreeBSD section of [Zonemaster::Engine installation]).

For details on supported versions of Perl, database engine and operating system
for Zonemaster::Backend, see the [declaration of prerequisites].

> **Note:** In addition to the normal dependencies, the post-installation
> smoke test instruction assumes that you have curl installed.

## 3. Installation on CentOS

### 3.1 Install Zonemaster::Backend and related dependencies (CentOS)

> **Note:** Zonemaster::LDNS and Zonemaster::Engine are not listed here as they
> are dealt with in the [prerequisites](#prerequisites) section.

Install dependencies available from binary packages:

```sh
sudo yum install perl-Module-Install perl-IO-CaptureOutput perl-String-ShellQuote perl-Net-Server redhat-lsb-core
```

Install dependencies not available from binary packages:

```sh
sudo cpanm Class::Method::Modifiers Config::IniFiles Daemon::Control JSON::RPC::Dispatch Net::IP::XS Parallel::ForkManager Plack::Builder Plack::Middleware::Debug Role::Tiny Router::Simple::Declare Starman
```

Install Zonemaster::Backend:
```sh
sudo cpanm Zonemaster::Backend
```

> The command above might try to install "DBD::Pg" and "DBD::mysql".
> You can ignore if it fails. The relevant libraries are installed further down in these instructions.

Add Zonemaster user (unless it already exists):
```sh
sudo useradd -r -c "Zonemaster daemon user" zonemaster
```

Install files to their proper locations:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
sudo install -v -m 755 -d /etc/zonemaster
sudo install -v -m 640 -g zonemaster ./backend_config.ini /etc/zonemaster/
sudo install -v -m 775 -g zonemaster -d /var/log/zonemaster
sudo install -v -m 775 -g zonemaster -d /var/run/zonemaster
sudo install -v -m 755 ./zm-rpcapi.lsb /etc/init.d/zm-rpcapi
sudo install -v -m 755 ./zm-testagent.lsb /etc/init.d/zm-testagent
sudo install -v -m 755 ./tmpfiles.conf /usr/lib/tmpfiles.d/zonemaster.conf
```

> If this is an update of Zonemster-Backend, you should remove any
> `/etc/init.d/zm-backend.sh` and `/etc/init.d/zm-centos.sh` (scripts from
> previous version of Zonemaster-Backend).

### 3.2 Database engine installation and configuration (CentOS)

Check the [declaration of prerequisites] to make sure your preferred combination
of operating system version and database engine version is supported.

The installation instructions below assumes that this is a new installation.
If you upgrade and want to keep the database, go to section
[7.4](#74-upgrade-zonemaster-database) first. If you instead want to start
from afresh, then go to section [7.3](#73-cleaning-up-the-database) and remove
the old database first.

If you keep the database, skip the initialization of the Zonemaster database,
but if you have removed the old Zonemaster database, then do the initialization.

#### 3.2.1 Instructions for MySQL (CentOS)

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= MySQL/' /etc/zonemaster/backend_config.ini
```

> **Note:** See the [backend configuration] documentation for details.

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

Initialize the database (unless you keep an old database):

> **Note:** If MySQL is newly installed, then one *may* have to set the root
> password for the following command to work

```sh
mysql --user=root --password < ./initial-mysql.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user
> called "zonemaster" with the password "zonemaster" (as stated in the config
> file). This user has just enough permissions to run the backend software.

#### 3.2.2 Instructions for PostgreSQL (CentOS)

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= PostgreSQL/' /etc/zonemaster/backend_config.ini
```

> **Note:** See the [backend configuration] documentation for details.

##### 3.2.2.1 PostgreSQL installation instructions for CentOS7

Add PostgreSQL package repository needed to get the appropriate PostgreSQL
binary package

> **Note:** PostgreSQL version should be equal or greater than 9.3. If
> PostgreSQL is already installed and is greater than 9.3 ignore the following
> commands   

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

##### 3.2.2.2 PostgreSQL installation instructions for CentOS8

> **Note:** Following commands are required only if PostgreSQL is not installed
> and is not greater or equal to version 9.3 

Install the PostgreSQL packages:

```sh
sudo yum -y install postgresql-server perl-DBD-Pg
```

Initialise PostgreSQL:

```sh
sudo postgresql-setup --initdb --unit postgresql
```

Configure:

```sh
# In the below file modify all instances of "ident" to "md5"
sudoedit /var/lib/pgsql/data/pg_hba.conf
```

To enable PostgreSQL from boot:

```sh
sudo systemctl enable postgresql
```

Start PostgreSQL:

```sh
sudo systemctl start postgresql
```

Verify PostgreSQL has started:

```sh
sudo systemctl status postgresql
```

##### 3.2.2.3 PostgreSQL installation instructions (common for CentOS7 and CentOS8)

Initialize Zonemaster database (unless you keep an old database):

```sh
sudo -u postgres psql -f ./initial-postgres.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user called
> "zonemaster" with the password "zonemaster" (as stated in the config file).
> This user has just enough permissions to run the backend software.

#### 3.2.3 Instructions for SQLite (CentOS)

>
> At this time there is no instruction for using SQLite on CentOS.
>

### 3.3 Service configuration and startup (CentOS)

Make sure our tmpfiles configuration takes effect:

```sh
sudo systemd-tmpfiles --create /usr/lib/tmpfiles.d/zonemaster.conf
```

Start the services:

```sh
sudo /etc/init.d/zm-rpcapi start
sudo /etc/init.d/zm-testagent start
```

Check that the service has started:

```sh
sudo /etc/init.d/zm-rpcapi status
sudo /etc/init.d/zm-testagent status
```
*Does not return any status as of now*


### 3.4 Post-installation (CentOS)

See the [post-installation] section for post-installation matters.


## 4. Installation on Debian

### 4.1 Install Zonemaster::Backend and related dependencies (Debian)

> **Note:** Zonemaster::LDNS and Zonemaster::Engine are not listed here as they
> are dealt with in the [prerequisites](#prerequisites) section.

Optionally install Curl (only needed for the post-installation smoke test):

```sh
sudo apt install curl
```

Install required locales:

```sh
locale -a | grep en_US.utf8 || echo en_US.UTF-8 UTF-8 | sudo tee -a /etc/locale.gen
locale -a | grep sv_SE.utf8 || echo sv_SE.UTF-8 UTF-8 | sudo tee -a /etc/locale.gen
locale -a | grep fr_FR.utf8 || echo fr_FR.UTF-8 UTF-8 | sudo tee -a /etc/locale.gen
locale -a | grep da_DK.utf8 || echo da_DK.UTF-8 UTF-8 | sudo tee -a /etc/locale.gen
sudo locale-gen
```

Install dependencies available from binary packages:

```sh
sudo apt install libclass-method-modifiers-perl libconfig-inifiles-perl libdbd-sqlite3-perl libdbi-perl libfile-sharedir-perl libfile-slurp-perl libhtml-parser-perl libio-captureoutput-perl libjson-pp-perl libjson-rpc-perl liblog-any-adapter-dispatch-perl liblog-any-perl liblog-dispatch-perl libmoose-perl libparallel-forkmanager-perl libplack-perl libplack-middleware-debug-perl librole-tiny-perl librouter-simple-perl libstring-shellquote-perl starman
```

Install dependencies not available from binary packages:

```sh
sudo cpanm Daemon::Control JSON::Validator Net::IP::XS Try::Tiny
```

Install Zonemaster::Backend:

```sh
sudo cpanm Zonemaster::Backend
```

> The command above might try to install "DBD::Pg" and "DBD::mysql".
> You can ignore if it fails. The relevant libraries are installed further down in these instructions.

Add Zonemaster user (unless it already exists):

```sh
sudo useradd -r -c "Zonemaster daemon user" zonemaster
```

Install files to their proper locations:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
sudo install -v -m 755 -d /etc/zonemaster
sudo install -v -m 775 -g zonemaster -d /var/log/zonemaster
sudo install -v -m 640 -g zonemaster ./backend_config.ini /etc/zonemaster/
sudo install -v -m 755 ./zm-rpcapi.lsb /etc/init.d/zm-rpcapi
sudo install -v -m 755 ./zm-testagent.lsb /etc/init.d/zm-testagent
sudo install -v -m 755 ./tmpfiles.conf /usr/lib/tmpfiles.d/zonemaster.conf
```

> If this is an update of Zonemster-Backend, you should remove any
> `/etc/init.d/zm-backend.sh` (script from previous version of Zonemaster-Backend).

### 4.2 Database engine installation and configuration (Debian)

Check the [declaration of prerequisites] to make sure your preferred combination
of operating system version and database engine version is supported.

The installation instructions below assumes that this is a new installation.
If you upgrade and want to keep the database, go to section
[7.4](#74-upgrade-zonemaster-database) first. If you instead want to start
from afresh, then go to section [7.3](#73-cleaning-up-the-database) and remove
the old database first.

If you keep the database, skip the initialization of the Zonemaster database,
but if you have removed the old Zonemaster database, then do the initialization.

#### 4.2.1 Instructions for MariaDB (Debian)

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= MySQL/' /etc/zonemaster/backend_config.ini
```

> **Note:** See the [backend configuration] documentation for details.

Install the database engine and its dependencies:

```sh
sudo apt install mariadb-server libdbd-mysql-perl
```

Initialize Zonemaster database (unless you keep an old database):

```sh
sudo mysql < $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')/initial-mysql.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user
> called "zonemaster" with the password "zonemaster" (as stated in the config
> file). This user has just enough permissions to run the backend software.

#### 4.2.2 Instructions for PostgreSQL (Debian)

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= PostgreSQL/' /etc/zonemaster/backend_config.ini
```

> **Note:** See the [backend configuration] documentation for details.

Install, configure and start database engine (and Perl bindings):

```sh
sudo apt install libdbd-pg-perl postgresql
```

Initialize Zonemaster database (unless you keep an old database):

```sh
sudo -u postgres psql -f $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')/initial-postgres.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user called
> "zonemaster" with the password "zonemaster" (as stated in the config file).
> This user has just enough permissions to run the backend software.


#### 4.2.3 Instructions for SQLite (Debian)

>
> At this time there is no instruction for configuring/creating a database in SQLite
>


### 4.3 Service configuration and startup (Debian)

Add services to the default runlevel:

```sh
sudo update-rc.d zm-rpcapi defaults
sudo update-rc.d zm-testagent defaults
```

Start the services:

```sh
sudo systemd-tmpfiles --create /usr/lib/tmpfiles.d/zonemaster.conf
sudo service zm-rpcapi start
sudo service zm-testagent start
```

If the `start` command did not give any output (depends on OS and version) then
check that the service has started with the following command (if you get output
with the `start` command, you probably do not get it with the `status` command).

```sh
sudo service zm-rpcapi status | cat
sudo service zm-testagent status | cat
```

### 4.4 Post-installation (Debian)

See the [post-installation] section for post-installation matters.


## 5. Installation on FreeBSD

For all commands below, acquire privileges, i.e. become root:

```sh
su -l
```

### 5.1 Install Zonemaster::Backend and related dependencies (FreeBSD)

> **Note:** Zonemaster::LDNS and Zonemaster::Engine are not listed here as they
> are dealt with in the [prerequisites](#prerequisites) section.

Install dependencies available from binary packages:

```sh
pkg install p5-Class-Method-Modifiers p5-Config-IniFiles p5-Daemon-Control p5-DBI p5-File-ShareDir p5-File-Slurp p5-HTML-Parser p5-IO-CaptureOutput p5-JSON-PP p5-JSON-RPC p5-Moose p5-Parallel-ForkManager p5-Plack p5-Plack-Middleware-Debug p5-Role-Tiny p5-Router-Simple p5-Starman p5-String-ShellQuote net-mgmt/p5-Net-IP-XS databases/p5-DBD-SQLite devel/p5-Log-Dispatch devel/p5-Log-Any devel/p5-Log-Any-Adapter-Dispatch
```

Optionally install Curl (only needed for the post-installation smoke test):

```sh
pkg install curl
```

Install dependencies not available from binary packages:

```sh
cpanm JSON::Validator
```

Install Zonemaster::Backend:

```sh
cpanm Zonemaster::Backend
```

> The command above might try to install "DBD::Pg" and "DBD::mysql".
> You can ignore if it fails. The relevant libraries are installed further down in these instructions.

Unless they already exist, add `zonemaster` user and `zonemaster` group
(the group is created automatically):

```sh
pw useradd zonemaster -s /sbin/nologin -d /nonexistent -c "Zonemaster daemon user"
```

Install files to their proper locations:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
install -v -m 755 -d /usr/local/etc/zonemaster
install -v -m 640 -g zonemaster ./backend_config.ini /usr/local/etc/zonemaster/
install -v -m 775 -g zonemaster -d /var/log/zonemaster
install -v -m 775 -g zonemaster -d /var/run/zonemaster
install -v -m 755 ./zm_rpcapi-bsd /usr/local/etc/rc.d/zm_rpcapi
install -v -m 755 ./zm_testagent-bsd /usr/local/etc/rc.d/zm_testagent
```

### 5.2 Database engine installation and configuration (FreeBSD)

Check the [declaration of prerequisites] to make sure your preferred combination
of operating system version and database engine version is supported.

The installation instructions below assumes that this is a new installation.
If you upgrade and want to keep the database, go to section
[7.4](#74-upgrade-zonemaster-database) first. If you instead want to start
from afresh, then go to section [7.3](#73-cleaning-up-the-database) and remove
the old database first.

If you keep the database, skip the initialization of the Zonemaster database,
but if you have removed the old Zonemaster database, then do the initialization.

#### 5.2.1 Instructions for MySQL (FreeBSD)

Configure Zonemaster::Backend to use the correct database engine:

```sh
sed -i '' '/[[:<:]]engine[[:>:]]/ s/=.*/= MySQL/' /usr/local/etc/zonemaster/backend_config.ini
```
> **Note:** See the [backend configuration] documentation for details.

Install, configure and start database engine (and Perl bindings):

```sh
pkg install mysql57-server p5-DBD-mysql
sysrc mysql_enable="YES"
service mysql-server start
```

Read the current root password for MySQL:

```sh
cat /root/.mysql_secret
```

Connect to MySQL interactively:

```sh
mysql -u root -h localhost -p
```

Reset root password in MySQL (required by MySQL). Replace
`<selected root password>` with the password from the file above
(or another one of your choice):

```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY '<selected root password>';
```

Logout from database:

```sql
exit;
```

Unless you keep an old database, initialize the database (and give the
root password when prompted):

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
mysql -u root -p < ./initial-mysql.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user
> called "zonemaster" with the password "zonemaster" (as stated in the config
> file). This user has just enough permissions to run the backend software.

#### 5.2.2 Instructions for PostgreSQL (FreeBSD)

Configure Zonemaster::Backend to use the correct database engine:

```sh
sed -i '' '/[[:<:]]engine[[:>:]]/ s/=.*/= PostgreSQL/' /usr/local/etc/zonemaster/backend_config.ini
```
> **Note:** See the [backend configuration] documentation for details.

Install, configure and start database engine (and Perl bindings):

```sh
pkg install databases/postgresql11-server databases/p5-DBD-Pg
sysrc postgresql_enable="YES"
service postgresql initdb
service postgresql start
```

Initialize Zonemaster database (unless you keep an old database):

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
psql -U postgres -f ./initial-postgres.sql
```

#### 5.2.3 Instructions for SQLite (FreeBSD)

>
> At this time there is no instruction for configuring and creating a database
> in SQLite.
>

### 5.3 Service startup (FreeBSD)

Enable services at startup:

```sh
sysrc zm_rpcapi_enable="YES"
sysrc zm_testagent_enable="YES"
```

Start services:

```sh
service zm_rpcapi start
service zm_testagent start
```

### 5.4 Post-installation (FreeBSD)

To check the running daemons run:

```sh
service mysql-server status      # If mysql-server is installed
service postgresql status        # If postgresql is installed
service zm_rpcapi status
service zm_testagent status
```

See the [post-installation] section for post-installation matters.


## 6. Installation on Ubuntu

Use the procedure for installation on [Debian](#2-installation-on-debian).


## 7. Post-installation

### 7.1 Smoke test

If you have followed the installation instructions for Zonemaster::Backend above,
you should be able to use the
API on localhost port 5000 as below. The command requires that `curl` is installed.

```sh
curl -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"version_info","id":"1"}' http://localhost:5000/ && echo
```

The command is expected to give an immediate JSON response similiar to:

```json
{"id":"1","jsonrpc":"2.0","result":{"zonemaster_backend":"2.0.2","zonemaster_engine":"v2.0.6"}}
```


### 7.2. What to do next?

* For a web interface, follow the [Zonemaster::GUI installation] instructions.
* For a command line interface, follow the [Zonemaster::CLI installation] instruction.
* For a JSON-RPC API, see the Zonemaster::Backend [JSON-RPC API] documentation.


### 7.3. Cleaning up the database

If, at some point, you want to delete all traces of Zonemaster in the database,
you can run the file `cleanup-mysql.sql` or file `cleanup-postgres.sql`
as a database administrator. Commands
for locating and running the file are below. It removes the user and drops the
database (obviously taking all data with it).

#### 7.3.1 MySQL

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
mysql --user=root --password < ./cleanup-mysql.sql
```

#### 7.3.2 PostgreSQL

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
sudo -u postgres psql -f ./cleanup-postgres.sql # MUST BE VERIFIED!
```

### 7.4 Upgrade Zonemaster database

If you upgrade your Zonemaster installation with a newer version of
Zonemaster-Backend and keep the database, then you might have to upgrade the
database to use it with the new version of Zonemaster-Backend. Please see the
[upgrade][README.md-upgrade] information.

-------

[Backend configuration]: Configuration.md
[Declaration of prerequisites]: https://github.com/zonemaster/zonemaster#prerequisites
[JSON-RPC API]: API.md
[Main Zonemaster repository]: https://github.com/zonemaster/zonemaster/blob/master/README.md
[Post-installation]: #7-post-installation
[README.md-upgrade]: /README.md#upgrade
[Zonemaster::CLI installation]: https://github.com/zonemaster/zonemaster-cli/blob/master/docs/Installation.md
[Zonemaster::GUI installation]: https://github.com/zonemaster/zonemaster-gui/blob/master/docs/Installation.md
[Zonemaster::Engine installation]: https://github.com/zonemaster/zonemaster-engine/blob/master/docs/Installation.md
[Zonemaster::Engine]: https://github.com/zonemaster/zonemaster-engine/blob/master/README.md
[Zonemaster::LDNS]: https://github.com/zonemaster/zonemaster-ldns/blob/master/README.md

Copyright (c) 2013 - 2017, IIS (The Internet Foundation in Sweden) \
Copyright (c) 2013 - 2017, AFNIC \
Creative Commons Attribution 4.0 International License

You should have received a copy of the license along with this
work.  If not, see <https://creativecommons.org/licenses/by/4.0/>.
