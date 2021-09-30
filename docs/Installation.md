# Installation

## Table of contents

* [1. Overview](#1-overview)
* [2. Prerequisites](#2-prerequisites)
* [3. Installation on CentOS](#3-installation-on-centos)
  * [3.1 Install Zonemaster::Backend and related dependencies (CentOS)](#31-install-zonemasterbackend-and-related-dependencies-centos)
  * [3.2 Database engine installation (CentOS)](#32-database-engine-installation-centos)
  * [3.3 Database configuration (CentOS)](#33-database-configuration-centos)
  * [3.4 Service configuration and startup (CentOS)](#34-service-configuration-and-startup-centos)
  * [3.5 Post-installation (CentOS)](#35-post-installation-centos)
* [4. Installation on Debian and Ubuntu](#4-installation-on-debian-and-ubuntu)
  * [4.1 Install Zonemaster::Backend and related dependencies (Debian/Ubuntu)](#41-install-zonemasterbackend-and-related-dependencies-debianubuntu)
  * [4.2 Database engine installation (Debian/Ubuntu)](#42-database-engine-installation-debianubuntu)
  * [4.3 Database configuration (Debian/Ubuntu)](#43-database-configuration-debianubuntu)
  * [4.4 Service configuration and startup (Debian/Ubuntu)](#44-service-configuration-and-startup-debianubuntu)
  * [4.5 Post-installation (Debian/Ubuntu)](#45-post-installation-debianubuntu)
* [5. Installation on FreeBSD](#5-installation-on-freebsd)
  * [5.1 Install Zonemaster::Backend and related dependencies (FreeBSD)](#51-install-zonemasterbackend-and-related-dependencies-freebsd)
  * [5.2 Database engine installation (FreeBSD)](#52-database-engine-installation-freebsd)
  * [5.3 Database configuration (FreeBSD)](#53-database-configuration-freebsd)
  * [5.4 Service startup (FreeBSD)](#54-service-startup-freebsd)
  * [5.5 Post-installation (FreeBSD)](#55-post-installation-freebsd)
* [6. Post-installation](#6-post-installation)
  * [6.1 Smoke test](#61-smoke-test)
  * [6.2 What to do next?](#62-what-to-do-next)
* [7. Upgrade Zonemaster database](#7-upgrade-zonemaster-database)
* [8. Installation with MariaDB](#8-installation-with-mariadb)
  * [8.1 MariaDB (CentOS)](#81-mariadb-centos)
  * [8.2. MariaDB (Debian/Ubuntu)](#82-mariadb-debianubuntu)
  * [8.3. MySQL (FreeBSD)](#83-mysql-freebsd)
* [9. Installation with PostgreSQL](#9-installation-with-postgresql)
  * [9.1. PostgreSQL (CentOS)](#91-postgresql-centos)
  * [9.2. PostgreSQL (Debian/Ubuntu)](#92-postgresql-debianubuntu)
  * [9.3. PostgreSQL (FreeBSD)](#93-postgresql-freebsd)
* [10. Cleaning up the database](#10-cleaning-up-the-database)
  * [10.1. MariaDB and MySQL](#101-mariadb-and-mysql)
  * [10.2. PostgreSQL](#102-postgresql)
  * [10.3. SQLite](#103-sqlite)

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

Prerequisite for FreeBSD is that the package system is updated and activated
(see the FreeBSD section of [Zonemaster::Engine installation]).

For details on supported versions of Perl, database engine and operating system
for Zonemaster::Backend, see the [declaration of prerequisites].


## 3. Installation on CentOS

### 3.1 Install Zonemaster::Backend and related dependencies (CentOS)

> **Note:** Zonemaster::LDNS and Zonemaster::Engine are not listed here as they
> are dealt with in the [prerequisites](#prerequisites) section.

Install dependencies available from binary packages:

```sh
sudo yum -y install jq perl-Class-Method-Modifiers perl-Config-IniFiles perl-DBD-SQLite perl-DBI perl-HTML-Parser perl-JSON-RPC perl-libwww-perl perl-Log-Dispatch perl-Net-Server perl-Parallel-ForkManager perl-Plack perl-Plack-Test perl-Role-Tiny perl-Router-Simple perl-String-ShellQuote perl-Test-NoWarnings perl-Test-Warn perl-Try-Tiny redhat-lsb-core
```

> **Note:** perl-Net-Server and perl-Test-Warn are listed here even though they
> are not direct dependencies. They are transitive dependencies with build
> problems when installed using cpanm.

Install dependencies not available from binary packages:

```sh
sudo cpanm Daemon::Control JSON::Validator Log::Any Log::Any::Adapter::Dispatch Starman Plack::Middleware::ReverseProxy
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
cd `perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")'`
sudo install -v -m 755 -d /etc/zonemaster
sudo install -v -m 640 -g zonemaster ./backend_config.ini /etc/zonemaster/
sudo install -v -m 775 -g zonemaster -d /var/log/zonemaster
sudo install -v -m 755 ./zm-rpcapi.lsb /etc/init.d/zm-rpcapi
sudo install -v -m 755 ./zm-testagent.lsb /etc/init.d/zm-testagent
sudo install -v -m 755 ./tmpfiles.conf /usr/lib/tmpfiles.d/zonemaster.conf
```

> If this is an update of Zonemaster-Backend, you should remove any
> `/etc/init.d/zm-backend.sh` and `/etc/init.d/zm-centos.sh` (scripts from
> previous version of Zonemaster-Backend).


### 3.2 Database engine installation (CentOS)

Check the [declaration of prerequisites] to make sure your preferred combination
of operating system version and database engine version is supported.

The installation instructions below assumes that this is a new installation.
If you upgrade and want to keep the database, go to section 
["Upgrade Zonemaster database"] first. If you instead want to start from afresh,
then go to section ["Cleaning up the database"] and remove the old database first.

If you keep the database, skip the initialization of the Zonemaster database,
but if you have removed the old Zonemaster database, then do the initialization.


#### 3.2.1 Instructions for SQLite (CentOS)

> **Note:** Zonemaster with SQLite is not meant for an installation with heavy
> load.

Create database directory:

```sh
sudo install -v -m 755 -o zonemaster -g zonemaster -d /var/lib/zonemaster
```

> Some parameters can be changed, see the [backend configuration] documentation
> for details.


#### 3.2.2 Instructions for other engines (CentOS)

See sections for [MariaDB][MariaDB instructions CentOS] and
[PostgreSQL][PostgreSQL instructions CentOS].


### 3.3 Database configuration (CentOS)

Created the database tables:

```sh
sudo -u zonemaster $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')/create_db.pl
```


### 3.4 Service configuration and startup (CentOS)

Make sure our tmpfiles configuration takes effect:

```sh
sudo systemd-tmpfiles --create /usr/lib/tmpfiles.d/zonemaster.conf
```

Enable services at boot time and start them:

```sh
sudo systemctl enable zm-rpcapi
sudo systemctl enable zm-testagent
sudo systemctl start zm-rpcapi
sudo systemctl start zm-testagent
```


### 3.5 Post-installation (CentOS)

See the [post-installation] section for post-installation matters.


## 4. Installation on Debian and Ubuntu

### 4.1 Install Zonemaster::Backend and related dependencies (Debian/Ubuntu)

> **Note:** Zonemaster::LDNS and Zonemaster::Engine are not listed here as they
> are dealt with in the [prerequisites](#prerequisites) section.

Install required locales:

```sh
sudo perl -pi -e 's/^# (da_DK\.UTF-8.*|en_US\.UTF-8.*|fi_FI\.UTF-8.*|fr_FR\.UTF-8.*|nb_NO\.UTF-8.*|sv_SE\.UTF-8.*)/$1/' /etc/locale.gen
sudo locale-gen
```

After the update, `locale -a` should at least list the following locales:
```
da_DK.utf8
en_US.utf8
fi_FI.utf8
fr_FR.utf8
nb_NO.utf8
sv_SE.utf8
```

Install dependencies available from binary packages:

```sh
sudo apt install jq libclass-method-modifiers-perl libconfig-inifiles-perl libdbd-sqlite3-perl libdbi-perl libfile-sharedir-perl libfile-slurp-perl libhtml-parser-perl libio-stringy-perl libjson-pp-perl libjson-rpc-perl liblog-any-adapter-dispatch-perl liblog-any-perl liblog-dispatch-perl libmoose-perl libparallel-forkmanager-perl libplack-perl libplack-middleware-debug-perl libplack-middleware-reverseproxy-perl librole-tiny-perl librouter-simple-perl libstring-shellquote-perl libtest-nowarnings-perl libtry-tiny-perl starman
```

> **Note**: libio-stringy-perl is listed here even though it's not a direct
> dependency. It's an undeclared dependency of libconfig-inifiles-perl.

Install dependencies not available from binary packages:

```sh
sudo cpanm Daemon::Control JSON::Validator
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
cd `perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")'`
sudo install -v -m 755 -d /etc/zonemaster
sudo install -v -m 775 -g zonemaster -d /var/log/zonemaster
sudo install -v -m 640 -g zonemaster ./backend_config.ini /etc/zonemaster/
sudo install -v -m 755 ./zm-rpcapi.lsb /etc/init.d/zm-rpcapi
sudo install -v -m 755 ./zm-testagent.lsb /etc/init.d/zm-testagent
sudo install -v -m 755 ./tmpfiles.conf /usr/lib/tmpfiles.d/zonemaster.conf
```

> If this is an update of Zonemaster-Backend, you should remove any
> `/etc/init.d/zm-backend.sh` (script from previous version of Zonemaster-Backend).


### 4.2 Database engine installation (Debian/Ubuntu)

Check the [declaration of prerequisites] to make sure your preferred combination
of operating system version and database engine version is supported.

The installation instructions below assumes that this is a new installation.
If you upgrade and want to keep the database, go to section 7
["Upgrade Zonemaster database"] first. If you instead want to start from afresh,
then go to section ["Cleaning up the database"] and remove the old database
first.

If you keep the database, skip the initialization of the Zonemaster database,
but if you have removed the old Zonemaster database, then do the initialization.


#### 4.2.1 Instructions for SQLite (Debian/Ubuntu)

> **Note:** Zonemaster with SQLite is not meant for an installation with heavy
> load.

Create database directory:

```sh
sudo install -v -m 755 -o zonemaster -g zonemaster -d /var/lib/zonemaster
```

> Some parameters can be changed, see the [backend configuration] documentation
> for details.


#### 4.2.2 Instructions for other engines (Debian/Ubuntu)

See sections for [MariaDB][MariaDB instructions Debian] and
[PostgreSQL][PostgreSQL instructions Debian].


### 4.3 Database configuration (Debian/Ubuntu)

Created the database tables:

```sh
sudo -u zonemaster $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')/create_db.pl
```


### 4.4 Service configuration and startup (Debian/Ubuntu)

Make sure our tmpfiles configuration takes effect:

```sh
sudo systemd-tmpfiles --create /usr/lib/tmpfiles.d/zonemaster.conf
```

Enable services at boot time and start them:

```sh
sudo systemctl enable zm-rpcapi
sudo systemctl enable zm-testagent
sudo systemctl start zm-rpcapi
sudo systemctl start zm-testagent
```


### 4.5 Post-installation (Debian/Ubuntu)

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
pkg install jq p5-Class-Method-Modifiers p5-Config-IniFiles p5-Daemon-Control p5-DBI p5-File-ShareDir p5-File-Slurp p5-HTML-Parser p5-JSON-PP p5-JSON-RPC p5-Moose p5-Parallel-ForkManager p5-Plack p5-Plack-Middleware-ReverseProxy p5-Role-Tiny p5-Router-Simple p5-Starman p5-String-ShellQuote p5-DBD-SQLite p5-Log-Dispatch p5-Log-Any p5-Log-Any-Adapter-Dispatch p5-JSON-Validator p5-YAML-LibYAML p5-Test-NoWarnings
```
<!-- JSON::Validator requires YAML::PP, but p5-JSON-Validator currently lacks a dependency on p5-YAML-LibYAML -->


Install Zonemaster::Backend:

```sh
cpanm Zonemaster::Backend
```

> The command above might try to install "DBD::Pg" and "DBD::mysql".
> You can ignore if it fails. The relevant libraries are installed further down in these instructions.

Unless they already exist, add `zonemaster` user and `zonemaster` group
(the group is created automatically):

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
pw useradd zonemaster -C freebsd-pwd.conf -s /sbin/nologin -d /nonexistent -c "Zonemaster daemon user"
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

### 5.2 Database engine installation (FreeBSD)

Check the [declaration of prerequisites] to make sure your preferred combination
of operating system version and database engine version is supported.

The installation instructions below assumes that this is a new installation.
If you upgrade and want to keep the database, go to section
["Upgrade Zonemaster database"] first. If you instead want to start from afresh,
then go to section ["Cleaning up the database"] and remove the old database
first.

If you keep the database, skip the initialization of the Zonemaster database,
but if you have removed the old Zonemaster database, then do the initialization.

#### 5.2.1 Instructions for SQLite (FreeBSD)

> **Note:** Zonemaster with SQLite is not meant for an installation with heavy
> load.

Configure Zonemaster::Backend to use the correct database path:

```sh
sed -i '' '/[[:<:]]database_file[[:>:]]/ s:=.*:= /var/db/zonemaster/db.sqlite:' /usr/local/etc/zonemaster/backend_config.ini
```

Create database directory:

```sh
install -v -m 755 -o zonemaster -g zonemaster -d /var/db/zonemaster
```

> Some parameters can be changed, see the [backend configuration] documentation
> for details.

#### 5.2.2 Instructions for other engines (FreeBSD)

See sections for [MariaDB][MariaDB instructions FreeBSD] and
[PostgreSQL][PostgreSQL instructions FreeBSD].


### 5.3 Database configuration (FreeBSD)

Created the database tables:

```sh
su -m zonemaster -c "`perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir(qw(Zonemaster-Backend))'`/create_db.pl"
```


### 5.4 Service startup (FreeBSD)

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

### 5.5 Post-installation (FreeBSD)

To check that the running daemons run:

```sh
service zm_rpcapi status
service zm_testagent status
```

See the [post-installation] section for post-installation matters.


## 6. Post-installation

### 6.1 Smoke test

If you have followed the installation instructions for Zonemaster::Backend above,
you should be able to use the API on localhost port 5000 as below.

```sh
zmtest zonemaster.net
```

The command is expected to immediately print out a testid,
followed by a percentage ticking up from 0% to 100%.
Once the number reaches 100% a JSON object is printed and zmtest terminates.


### 6.2. What to do next?

* For a web interface, follow the [Zonemaster::GUI installation] instructions.
* For a command line interface, follow the [Zonemaster::CLI installation] instruction.
* For a JSON-RPC API, see the Zonemaster::Backend [JSON-RPC API] documentation.


## 7. Upgrade Zonemaster database

If you upgrade your Zonemaster installation with a newer version of
Zonemaster-Backend and keep the database, then you might have to upgrade the
database to use it with the new version of Zonemaster-Backend. Please see the
[upgrade][README.md-upgrade] information.


## 8. Installation with MariaDB

First follow the installation instructions for the OS in question, and then go
to this section to install MariaDB.

### 8.1. MariaDB (CentOS)

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= MySQL/' /etc/zonemaster/backend_config.ini
```

> **Note:** See the [backend configuration] documentation for details.

Install, configure and start database engine:

```sh
sudo yum -y install mariadb-server
sudo systemctl enable mariadb
sudo systemctl start mariadb
```

To create the database and the database user (unless you keep an old database)
run the command. Edit the script first if you want a non-default user name or
password.

```sh
sudo mysql < $(perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")')/initial-mysql.sql
```

Update the `/etc/zonemaster/backend_config.ini` file with username and password
if non-default values are used.

Now go back to "[Database configuration](#33-database-configuration-centos)"
to create the database tables and then continue with the steps after that.


### 8.2. MariaDB (Debian/Ubuntu)

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= MySQL/' /etc/zonemaster/backend_config.ini
```

> **Note:** See the [backend configuration] documentation for details.

Install the database engine and its dependencies:

```sh
sudo apt install mariadb-server libdbd-mysql-perl
```

To create the database and the database user (unless you keep an old database)
run the command. Edit the script first if you want a non-default user name or
password.

```sh
sudo mysql < $(perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")')/initial-mysql.sql
```

Update the `/etc/zonemaster/backend_config.ini` file with username and password
if non-default values are used.

Now go back to "[Database configuration](#43-database-configuration-debianubuntu)"
to create the database tables and then continue with the steps after that.


### 8.3. MySQL (FreeBSD)

> MariaDB is not compatible with Zonemaster on FreeBSD. MySQL is used instead.

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

Read the current root password for MySQL (unless it has been changed
already).

```sh
cat /root/.mysql_secret
```

Change password for MySQL root (required by MySQL). Replace 
`<selected root password>` with a password of your choice. Use the password
from `/root/.mysql_secret` when prompted this time.

```sh
/usr/local/bin/mysqladmin -u root -p password '<selected root password>'
```

To create the database and the database user (unless you keep an old database)
run the command. Edit the script first if you want a non-default user name or
password. Use the MySQL root password when prompted.

```sh
mysql -u root -p < `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`/initial-mysql.sql
```

Update the `/etc/zonemaster/backend_config.ini` file with username and password
if non-default values are used.

Now go back to "[Database configuration](#53-database-configuration-freebsd)"
to create the database tables and then continue with the steps after that.


## 9. Installation with PostgreSQL

First follow the installation instructions for the OS in question, and then go
to this section to install PostgreSQL.

### 9.1. PostgreSQL (CentOS)

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= PostgreSQL/' /etc/zonemaster/backend_config.ini
```

> **Note:** See the [backend configuration] documentation for details.

Install, configure and start database engine:

* On CentOS 7:

  ```sh
  sudo rpm -iUvh https://yum.postgresql.org/9.3/redhat/rhel-7-x86_64/pgdg-centos93-9.3-3.noarch.rpm
  sudo yum -y install postgresql93-server perl-DBD-Pg
  sudo /usr/pgsql-9.3/bin/postgresql93-setup initdb
  sudo sed -i '/^[^#]/ s/ident$/md5/' /var/lib/pgsql/9.3/data/pg_hba.conf
  sudo systemctl enable postgresql-9.3
  sudo systemctl start postgresql-9.3
  ```

* On CentOS 8:

  ```sh
  sudo yum -y install postgresql-server perl-DBD-Pg
  sudo postgresql-setup --initdb --unit postgresql
  sudo sed -i '/^[^#]/ s/ident$/md5/' /var/lib/pgsql/data/pg_hba.conf
  sudo systemctl enable postgresql
  sudo systemctl start postgresql
  ```

Create the Zonemaster database and user (unless you keep an old database):

```sh
sudo -u postgres psql -f $(perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")')/initial-postgres.sql
```

Update the `/etc/zonemaster/backend_config.ini` file with username and password
if non-default values are used.

Now go back to "[Database configuration](#33-database-configuration-centos)"
to create the database tables and then continue with the steps after that.


### 9.2. PostgreSQL (Debian/Ubuntu)

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= PostgreSQL/' /etc/zonemaster/backend_config.ini
```

Install the database engine and Perl bindings:

```sh
sudo apt install postgresql libdbd-pg-perl
```

> **Note:** See the [backend configuration] documentation for details.

Create the Zonemaster database and user (unless you keep an old database):

```sh
sudo -u postgres psql -f $(perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")')/initial-postgres.sql
```

Update the `/etc/zonemaster/backend_config.ini` file with username and password
if non-default values are used.

Now go back to "[Database configuration](#43-database-configuration-debianubuntu)"
to create the database tables and then continue with the steps after that.


### 9.3. PostgreSQL (FreeBSD)

Configure Zonemaster::Backend to use the correct database engine:

```sh
sed -i '' '/[[:<:]]engine[[:>:]]/ s/=.*/= PostgreSQL/' /usr/local/etc/zonemaster/backend_config.ini
```
> **Note:** See the [backend configuration] documentation for details.

Install, configure and start database engine (and Perl bindings):

```sh
pkg install postgresql12-server p5-DBD-Pg
sysrc postgresql_enable="YES"
service postgresql initdb
service postgresql start
```

7
To create the database and the database user (unless you keep an old database)
run the command. Edit the script first if you want a non-default user name or
password.

```sh
psql -U postgres -f `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`/initial-postgres.sql
```

Update the `/etc/zonemaster/backend_config.ini` file with username and password
if non-default values are used.

Now go back to "[Database configuration](#53-database-configuration-freebsd)"
to create the database tables and then continue with the steps after that.


## 10. Cleaning up the database

If, at some point, you want to delete all traces of Zonemaster in the database,
you can run the file `cleanup-mysql.sql` or file `cleanup-postgres.sql`
as a database administrator. Commands
for locating and running the file are below. It removes the user and drops the
database (obviously taking all data with it).

### 10.1. MariaDB and MySQL

```sh
mysql --user=root -p < `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`/cleanup-mysql.sql
```

### 10.2. PostgreSQL

CentOS, Debian and Ubuntu:

```sh
sudo -u postgres psql -f $(perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")')/cleanup-postgres.sql # MUST BE VERIFIED!
```

FreeBSD (as root):

```sh
psql -U postgres -f `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`/cleanup-postgres.sql
```

### 10.3. SQLite

Remove the database file and recreate it following the installation instructions above.

-------

["Cleaning up the database"]:         #10-cleaning-up-the-database
["Upgrade Zonemaster database"]:      #7-upgrade-zonemaster-database
[Backend configuration]:              Configuration.md
[Declaration of prerequisites]:       https://github.com/zonemaster/zonemaster#prerequisites
[JSON-RPC API]:                       API.md
[Main Zonemaster repository]:         https://github.com/zonemaster/zonemaster/blob/master/README.md
[MariaDB instructions CentOS]:        #81-mariadb-centos
[MariaDB instructions Debian]:        #82-mariadb-debianubuntu
[MariaDB instructions FreeBSD]:       #83-mysql-freebsd
[Post-installation]:                  #6-post-installation
[PostgreSQL instructions CentOS]:     #91-postgresql-centos
[PostgreSQL instructions Debian]:     #92-postgresql-debianubuntu
[PostgreSQL instructions FreeBSD]:    #93-postgresql-freebsd
[README.md-upgrade]:                  README.md#upgrade
[Upgrade database]:                   #7-upgrade-zonemaster-database
[Zonemaster::CLI installation]:       https://github.com/zonemaster/zonemaster-cli/blob/master/docs/Installation.md
[Zonemaster::Engine installation]:    https://github.com/zonemaster/zonemaster-engine/blob/master/docs/Installation.md
[Zonemaster::Engine]:                 https://github.com/zonemaster/zonemaster-engine/blob/master/README.md
[Zonemaster::GUI installation]:       https://github.com/zonemaster/zonemaster-gui/blob/master/docs/Installation.md
[Zonemaster::LDNS]:                   https://github.com/zonemaster/zonemaster-ldns/blob/master/README.md
