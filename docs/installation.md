# Zonemaster Backend installation guide

## Overview

This document walks you through the installation of the Zonemaster *Backend* in
the following sections:

1. [Choices](#choices) lets you make all choices up front that this guide
presumes you've made.  
2. [Prerequisites](#prerequisites) lets you check all
assumptions made by this guide about pre-installed software.  
3. [Dependencies](#dependencies) shows you how to install all software that your
Zonemaster *Backend* will depend on.  
4. [Installation](#installation) shows you how to install the *Backend* itself.  
5. [Configuration](#configuration) shows you the database and *Backend* configuration.  
6. [Startup](#startup) shows you how to start the *Backend*.  
7. [Post-installation sanitycheck](#post-installation-sanity-check) lets you 
   verify that your *Backend* has started correctly.

This document ends with appendices:

* [Quick installation using a Docker container](#quick-installation-using-a-docker-container) 
* [Administrative tasks](#administrative-tasks)


## 1. Choices

In various places throughout this guide you will be assumed to have made various
choises.  This section lists all those choices so you can make them up front.


### 1.1 Operating system

Zonemaster *Backend* needs to run on an operating system. One can choose any of
the following OS to install the *Backend*.

* CentOS 
* Debian 
* FreeBSD 
* Ubuntu


### 1.2 *Database engine*

Zonemaster *Backend* needs a database engine.  The choice for the database are
as follows :

* MySQL 
* PostgreSQL (currently no instructions for CentOS) 
* SQLite (currently no instructions for any OS)


## 2. Prerequisites

This guide assumes that the following softwares are already installed on the
target system:

* the chosen operating system sudo (only for installation and other
  administrative tasks) 
* cpanm (only for installation) 
* curl (only for post-installation sanity check)
* Zonemaster *Engine* is installed in your respective OS 
  [installtion instruction](https://github.com/dotse/zonemaster-engine/blob/master/docs/installation.md).

## 3. Dependencies

This section shows you how to install all software that your Zonemaster
*Backend* will depend on.  Find and follow the subsection relevant for your
chosen operating system below.


### 3.1 Installing dependencies on CentOS

```sh 
sudo yum install perl-Module-Install perl-IO-CaptureOutput
perl-String-ShellQuote sudo cpanm -i Config::IniFiles Daemon::Control
JSON::RPC::Dispatch Parallel::ForkManager Plack::Builder
Plack::Middleware::Debug Router::Simple::Declare Starman 
```

Install the chosen database engine and related dependencies.

#### 3.1.1 MySQL

```sh sudo yum install wget wget
http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm sudo rpm -ivh
mysql-community-release-el7-5.noarch.rpm sudo yum install mysql-server
perl-DBD-mysql sudo systemctl start mysqld 
```

#### 3.1.2 PostgreSQL

>
> At this time there is no instruction for using PostgreSQL on CentOS.
>

#### 3.1.3 SQLite

>
> At this time there is no instruction for using SQLite on CentOS.
>


### 3.2 Installing dependencies on Debian and Ubuntu

```sh 
sudo apt-get update sudo apt-get install git libmodule-install-perl
libconfig-inifiles-perl libdbd-sqlite3-perl starman libio-captureoutput-perl
libproc-processtable-perl libstring-shellquote-perl librouter-simple-perl
libclass-method-modifiers-perl libtext-microtemplate-perl libdaemon-control-perl
sudo cpanm -i Plack::Middleware::Debug Parallel::ForkManager JSON::RPC 
```

Note: The Perl modules `Parallel::ForkManager` and `JSON::RPC` exist as Debian
packages, but with versions too old to be useful for us.

Install the chosen database engine and related dependencies.

#### 3.2.1 MySQL

```sh 
sudo apt-get install mysql-server libdbd-mysql-perl 
```

#### 3.2.2 PostgreSQL

```sh 
sudo apt-get install libdbd-pg-perl postgresql 
```

#### 3.2.3 SQLite

>
> At this time there is no instruction for using SQLite on Debian and Ubuntu.
>

### 3.3 Installing dependencies on FreeBSD

```sh 
sudo pkg install p5-Config-IniFiles p5-DBI p5-File-Slurp p5-HTML-Parser
p5-IO-CaptureOutput p5-JSON p5-JSON-RPC p5-Locale-libintl p5-libwww p5-Moose
p5-Plack p5-Router-Simple p5-String-ShellQuote p5-Starman p5-File-ShareDir
p5-Parallel-ForkManager p5-Daemon-Control p5-Module-Install p5-DBD-SQLite
p5-Plack-Middleware-Debug 
```

Install the chosen database engine and related dependencies.

#### 3.3.1 MySQL

```sh 
sudo pkg install mysql56-server p5-DBD-mysql 
```

>
> At this time there is no instruction for configuring and starting MySQL on
> FreeBSD.
>

#### 3.3.2 PostgreSQL

```sh 
sudo pkg install postgresql93-server p5-DBD-Pg echo
'postgresql_enable="YES"' | sudo tee -a /etc/rc.conf sudo service postgresql
initdb sudo service postgresql start 
```

#### 3.3.3 SQLite

>
> At this time there is no instruction for using SQLite on FreeBSD.
>


## 4. Installation of the backend

```sh 
sudo cpanm Zonemaster::WebBackend 
```


## 5. Configuration 

There are three steps in this section: 
1. Create a placeholder for logs and copy the config file to the respective directory.  
2. Set up service scripts for the relevant operating system 
3. Database configuration and creation


### 5.1 Directory and file manipulation

```sh 
sudo mkdir /etc/zonemaster 
mkdir "$HOME/logs" 
```

The Zonemaster::WebBackend module installs a number of configuration files in a
shared data directory.  This section refers to the shared data directory as the
current directory, so locate it and go there like this:

```sh 
cd `perl -MFile::ShareDir -le 'print
File::ShareDir::dist_dir("Zonemaster-WebBackend")'` 
```

Copy the `backend_config.ini` file to `/etc/zonemaster`.

```sh 
sudo cp ./backend_config.ini /etc/zonemaster/ 
```

### 5.2.1 CentOS

Copy the example init file to the system directory.  You may wish to edit the
file in order to use a more suitable user and group.  As distributed, it uses
the MySQL user and group, since we can be sure that exists and it shouldn't mess
up anything included with the system.

```sh 
sudo cp ./zm-centos.sh /etc/init.d/ 
sudo chmod +x /etc/init.d/zm-centos.sh
```

### 5.2.2 Debian and Ubuntu

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

### 5.2.3 FreeBSD

>
> At this time there is no instruction for running Zonemaster *Web backends* nor
> *Workers* as services on FreeBSD.
>


### 5.3.1 Configuring and creating a database in MySQL

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


### 5.3.2 Configuring and creating a database in PostgreSQL 

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
For PostgreSQL, commands for creating the database vary with respect to the OS

#### 5.3.2.1 CentOS

>
> At this time there is no instruction for configuring and creating a database
> in PostgreSQL on CentOS.
>

### 5.3.2.2 Debian and Ubuntu

Connect to Postgres as a user with administrative privileges and set things up:

```sh 
sudo -u postgres psql -f ./initial-postgres.sql 
```

This creates a database called `zonemaster`, as well as a user called
"zonemaster" with the password "zonemaster" (as stated in the config file). This
user has just enough permissions to run the backend software.

### 5.3.3 FreeBSD

Start the PostgreSQL server according to its instructions then initiate the
database using the following script.

```sh 
psql -U pgsql -f ./initial-postgres.sql template1 
```

### 5.3.3 Configuring and creating a SQLite database

>
> At this time there is no instruction for configuring and creating a database
> in PostgreSQL on CentOS.
>


## 6. Startup

### 6.1 Starting services on CentOS

```sh 
sudo systemctl start zm-centos 
```

### 6.2 Starting services on Debian and Ubuntu

Start the processes, point pid and log to a appropriate-for-your-OS location
(first line is the API, second is the test runner itself)

```sh 
starman --error-log="$HOME/logs/backend_starman.log"
--listen=127.0.0.1:5000 --pid="$HOME/logs/starman.pid" --daemonize
/usr/local/bin/zonemaster_webbackend.psgi 
```

Starting the starman part that listens for and answers the JSON::RPC requests 

```sh 
sudo service zm-backend.sh start 
```

This only needs to be run as root in order to make sure the log file can be
opened. The `starman` process will change to the `www-data` user as soon as it
can, and all of the real work will be done as that user.

>
> At this time there is no instruction for running Zonemaster *Workers* as
> services on Debian and Ubuntu.
>


### 6.3 Starting services on FreeBSD

Start the processes, point pid and log to a appropriate-for-your-OS location
(first line is the API, second is the test runner itself)

```sh 
starman --error-log="$HOME/logs/error.log"
--pid-file="$HOME/logs/starman.pid" --listen=127.0.0.1:5000 --daemonize
/usr/local/bin/zonemaster_webbackend.psgi zm_wb_daemon start 
```

>
> At this time there is no instruction for running Zonemaster *Web backends* nor
> *Workers* as services on FreeBSD.
>


## 7. Post-installation sanity check

If you followed this instructions to the letter, you should be able to use the
API on localhost port 5000, like this:

```sh 
curl -s -H "Content-Type: application/json" -d
'{"jsonrpc":"2.0","method":"version_info","id":"1"}' http://localhost:5000/ &&
echo 
```

The command is expected to give an immediate JSON response similiar to :

```sh
{"id":140715758026879,"jsonrpc":"2.0","result":"Zonemaster Test Engine Version:
v1.0.2"}
```

# Appendices

## Quick installation using a Docker container

Install the docker package on your OS

Follow the installation instructions for your OS ->
https://docs.docker.com/engine/installation/linux/

Pull the docker image containing the complete Zonemaster distribution (GUI +
Backend + Engine)

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

### *Performing administrative tasks for MySQL*

If, at some point, you want to delete all traces of Zonemaster in the database,
you can run the file `cleanup-mysql.sql` as a database administrator.  It
removes the user and drops the database (obviously taking all data with it).

Locate `cleanup-mysql.sql` using this command:

```sh 
perl -MFile::ShareDir -le 'print
File::ShareDir::dist_file("Zonemaster-WebBackend", "cleanup-mysql.sql")' 
```


### *Performing administrative tasks on Debian and Ubuntu*

If you would like to kill the starman process, you can issue this command:

```sh 
kill `cat "$HOME/logs/starman.pid"` 
```
