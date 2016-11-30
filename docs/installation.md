# Zonemaster Backend installation guide

## Overview

Zonemaster *Backend* needs to run on an operating system. One can choose any of
the following OS to install the *Backend* after having the required
[Prerequisites](#prerequisites).

* [CentOS](#centos) 7 - 64 bits 
* [Debian](#Debian) 8 (Jessie) - 64 bits 
* [Ubuntu](#Debian)
* [FreeBSD](#FreeBSD) 

```
Note: We assume the installation instructions will work for earlier OS
versions too. If you have any issue in installing the Zonemaster engine with
earlier versions, please send a mail with details to contact@zonemaster.net 
```

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

### 3.1 Installing dependencies on CentOS

```sh 
sudo yum install perl-Module-Install perl-IO-CaptureOutput perl-String-ShellQuote sudo cpanm -i Config::IniFiles Daemon::Control JSON::RPC::Dispatch Parallel::ForkManager Plack::Builder Plack::Middleware::Debug Router::Simple::Declare Starman 
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
cd `perl -MFile::ShareDir -le 'print
File::ShareDir::dist_dir("Zonemaster-WebBackend")'`
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

```
Note : Only run the above command during an initial installation of the
Zonemaster backend. If you do this on an existing system, you will wipe out the
data in your database.

If, at some point, you want to delete all traces of Zonemaster in the database,
you can run the file `cleanup-mysql.sql` as a database administrator.  It
removes the user and drops the database (obviously taking all data with it).
```

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
## Debian & Ubuntu

## FreeBSD


 
