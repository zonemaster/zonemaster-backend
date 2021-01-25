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
sudo yum install jq perl-Class-Method-Modifiers perl-Config-IniFiles perl-DBD-SQLite perl-DBI perl-HTML-Parser perl-JSON-RPC perl-libwww-perl perl-Log-Dispatch perl-Net-Server perl-Parallel-ForkManager perl-Plack perl-Plack-Test perl-Role-Tiny perl-Router-Simple perl-String-ShellQuote perl-Test-Warn redhat-lsb-core
```

> **Note:** perl-Net-Server and perl-Test-Warn are listed here even though they
> are not direct dependencies. They are transitive dependencies with build
> problems when installed using cpanm.

Install dependencies not available from binary packages:

```sh
sudo cpanm Daemon::Control JSON::Validator Log::Any Log::Any::Adapter::Dispatch Starman Try::Tiny
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
sudo install -v -m 775 -g zonemaster -d /var/run/zonemaster
sudo install -v -m 755 ./zm-rpcapi.lsb /etc/init.d/zm-rpcapi
sudo install -v -m 755 ./zm-testagent.lsb /etc/init.d/zm-testagent
sudo install -v -m 755 ./tmpfiles.conf /usr/lib/tmpfiles.d/zonemaster.conf
```

> If this is an update of Zonemaster-Backend, you should remove any
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


#### 3.2.1 Instructions for MariaDB (CentOS)

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= MySQL/' /etc/zonemaster/backend_config.ini
sudo sed -i '/\bdatabase_name\b/ s/=.*/= zonemaster/' /etc/zonemaster/backend_config.ini
```

> **Note:** See the [backend configuration] documentation for details.

Install, configure and start database engine:

```sh
sudo yum install mariadb-server
sudo systemctl enable mariadb
sudo systemctl start mariadb
```

Initialize the database (unless you keep an old database):

```sh
sudo mysql < $(perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")')/initial-mysql.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user
> called "zonemaster" with the password "zonemaster" (as stated in the config
> file). This user has just enough permissions to run the backend software.


#### 3.2.2 Instructions for PostgreSQL (CentOS)

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= PostgreSQL/' /etc/zonemaster/backend_config.ini
sudo sed -i '/\bdatabase_name\b/ s/=.*/= zonemaster/' /etc/zonemaster/backend_config.ini
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

Initialize Zonemaster database (unless you keep an old database):

```sh
sudo -u postgres psql -f $(perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")')/initial-postgres.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user called
> "zonemaster" with the password "zonemaster" (as stated in the config file).
> This user has just enough permissions to run the backend software.


#### 3.2.3 Instructions for SQLite (CentOS)

> **Note:** Zonemaster with SQLite backend is not yet considered stable and anyway
> not meant for an installation with heavy load.

Configure Zonemaster::Backend to use the correct database engine and database
path:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= SQLite/' /etc/zonemaster/backend_config.ini
sudo sed -i '/\bdatabase_name\b/ s:=.*:= /var/lib/zonemaster/db.sqlite:' /etc/zonemaster/backend_config.ini
```

Create database directory, set correct ownership and create database:

```sh
cd `perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")'`
sudo install -v -m 755 -u zonemaster -g zonemaster -d /var/lib/zonemaster
sudo perl create_db_sqlite.pl
sudo chown zonemaster:zonemaster /var/lib/zonemaster/db.sqlite
```

> **Note:** See the [backend configuration] documentation for details.


### 3.3 Service configuration and startup (CentOS)

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


### 3.4 Post-installation (CentOS)

See the [post-installation] section for post-installation matters.


## 4. Installation on Debian

### 4.1 Install Zonemaster::Backend and related dependencies (Debian)

> **Note:** Zonemaster::LDNS and Zonemaster::Engine are not listed here as they
> are dealt with in the [prerequisites](#prerequisites) section.

Install required locales:

```sh
sudo perl -pi -e 's/^# (da_DK\.UTF-8.*|en_US\.UTF-8.*|fr_FR\.UTF-8.*|nb_NO\.UTF-8.*|sv_SE\.UTF-8.*)/$1/' /etc/locale.gen
sudo locale-gen
```

After the update, `locale -a` should at least list the following locales:
```
da_DK.utf8
en_US.utf8
fr_FR.utf8
nb_NO.utf8
sv_SE.utf8
```

Install dependencies available from binary packages:

```sh
sudo apt install jq libclass-method-modifiers-perl libconfig-inifiles-perl libdbd-sqlite3-perl libdbi-perl libfile-sharedir-perl libfile-slurp-perl libhtml-parser-perl libjson-pp-perl libjson-rpc-perl liblog-any-adapter-dispatch-perl liblog-any-perl liblog-dispatch-perl libmoose-perl libparallel-forkmanager-perl libplack-perl libplack-middleware-debug-perl librole-tiny-perl librouter-simple-perl libstring-shellquote-perl libtry-tiny-perl starman
```

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

Install the database engine and its dependencies:

```sh
sudo apt install mariadb-server libdbd-mysql-perl
```

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= MySQL/' /etc/zonemaster/backend_config.ini
sudo sed -i '/\bdatabase_name\b/ s/=.*/= zonemaster/' /etc/zonemaster/backend_config.ini
```

> **Note:** See the [backend configuration] documentation for details.

Initialize Zonemaster database (unless you keep an old database):

```sh
sudo mysql < $(perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")')/initial-mysql.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user
> called "zonemaster" with the password "zonemaster" (as stated in the config
> file). This user has just enough permissions to run the backend software.


#### 4.2.2 Instructions for PostgreSQL (Debian)

Install database engine and Perl bindings:

```sh
sudo apt install postgresql libdbd-pg-perl
```

Configure Zonemaster::Backend to use the correct database engine:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= PostgreSQL/' /etc/zonemaster/backend_config.ini
sudo sed -i '/\bdatabase_name\b/ s/=.*/= zonemaster/' /etc/zonemaster/backend_config.ini
```

> **Note:** See the [backend configuration] documentation for details.

Initialize Zonemaster database (unless you keep an old database):

```sh
sudo -u postgres psql -f $(perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")')/initial-postgres.sql
```

> **Note:** This creates a database called `zonemaster`, as well as a user called
> "zonemaster" with the password "zonemaster" (as stated in the config file).
> This user has just enough permissions to run the backend software.


#### 4.2.3 Instructions for SQLite (Debian)

> **Note:** Zonemaster with SQLite backend is not yet considered stable and anyway
> not meant for an installation with heavy load.

> All binaries and Perl bindings are already installed.

Configure Zonemaster::Backend to use the correct database engine and database
path:

```sh
sudo sed -i '/\bengine\b/ s/=.*/= SQLite/' /etc/zonemaster/backend_config.ini
sudo sed -i '/\bdatabase_name\b/ s:=.*:= /var/lib/zonemaster/db.sqlite:' /etc/zonemaster/backend_config.ini
```

Create database directory, set correct ownership and create database:

```sh
cd `perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")'`
sudo install -v -m 755 -o zonemaster -g zonemaster -d /var/lib/zonemaster
sudo perl create_db_sqlite.pl
```

> SQLite will not run as a daemon and does not need to be started.

> **Note:** See the [backend configuration] documentation for details.


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
pkg install jq p5-Class-Method-Modifiers p5-Config-IniFiles p5-Daemon-Control p5-DBI p5-File-ShareDir p5-File-Slurp p5-HTML-Parser p5-JSON-PP p5-JSON-RPC p5-Moose p5-Parallel-ForkManager p5-Plack p5-Role-Tiny p5-Router-Simple p5-Starman p5-String-ShellQuote p5-DBD-SQLite p5-Log-Dispatch p5-Log-Any p5-Log-Any-Adapter-Dispatch p5-JSON-Validator p5-YAML-LibYAML
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
sed -i '' '/[[:<:]]database_name[[:>:]]/ s/=.*/= zonemaster/' /usr/local/etc/zonemaster/backend_config.ini
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
sed -i '' '/[[:<:]]database_name[[:>:]]/ s/=.*/= zonemaster/' /usr/local/etc/zonemaster/backend_config.ini
```
> **Note:** See the [backend configuration] documentation for details.

Install, configure and start database engine (and Perl bindings):

```sh
pkg install postgresql12-server p5-DBD-Pg
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

> **Note:** Zonemaster with SQLite backend is not yet considered stable and anyway
> not meant for an installation with heavy load.

> All binaries and Perl bindings are already installed.

Configure Zonemaster::Backend to use the correct database engine and database
path:

```sh
sed -i '' '/[[:<:]]engine[[:>:]]/ s/=.*/= SQLite/' /usr/local/etc/zonemaster/backend_config.ini
sed -i '' '/[[:<:]]database_name[[:>:]]/ s:=.*:= /var/db/zonemaster/db.sqlite:' /usr/local/etc/zonemaster/backend_config.ini
```

Create database directory, set correct ownership and create database:

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
install -v -m 755 -o zonemaster -g zonemaster -d /var/db/zonemaster
ZONEMASTER_BACKEND_CONFIG_FILE="/usr/local/etc/zonemaster/backend_config.ini" su -m zonemaster -c "perl create_db_sqlite.pl"
```

> SQLite will not run as a daemon and does not need to be started.

> **Note:** See the [backend configuration] documentation for details.

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

Use the procedure for installation on [Debian](#4-installation-on-debian).


## 7. Post-installation

### 7.1 Smoke test

If you have followed the installation instructions for Zonemaster::Backend above,
you should be able to use the API on localhost port 5000 as below.

```sh
zmtest zonemaster.net
```

The command is expected to immediately print out a testid,
followed by a percentage ticking up from 0% to 100%.
Once the number reaches 100% a JSON object is printed and zmtest terminates.


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

#### 7.3.3 SQLite

Remove the database file and recreate it following the installation instructions above.

### 7.4 Upgrade Zonemaster database

If you upgrade your Zonemaster installation with a newer version of
Zonemaster-Backend and keep the database, then you might have to upgrade the
database to use it with the new version of Zonemaster-Backend. Please see the
[upgrade][README.md-upgrade] information.

For SQLite database upgrading is not needed as of now.

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
