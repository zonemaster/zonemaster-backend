# Upgrade to 8.0.0

On FreeBSD run the following command first to become root:

```sh
su -l
```

## New dependencies

Depending on the used OS, run the corresponding command.

### FreeBSD

```sh
pkg install p5-Plack-Middleware-ReverseProxy
```

### Debian / Ubuntu

```sh
sudo apt-get install libplack-middleware-reverseproxy-perl
```

### Centos

```sh
sudo cpanm Plack::Middleware::ReverseProxy
```


## Upgrading init scripts

Go to the share folder:
```
cd `perl -MFile::ShareDir=dist_dir -E 'say dist_dir("Zonemaster-Backend")'`
```

And then install the `zm-rpcapi` daemon (`zm_rpcapi` on FreeBSD).

### FreeBSD

```
install -v -m 755 ./zm_rpcapi-bsd /usr/local/etc/rc.d/zm_rpcapi
```

### Debian / Ubuntu / CentOS

```
sudo install -v -m 755 ./zm-rpcapi.lsb /etc/init.d/zm-rpcapi
```


## Upgrading the database

If your Zonemaster database was created by a Zonemaster-Backend version smaller
than v8.0.0, and not upgraded, use the following instructions.

> Depending on the database size this upgrade can take some time (around
> 30 minutes for a database with 1 million entries)

> You may need to run the command with `sudo`.

### SQLite

Run
```sh
cd $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')
perl patch_sqlite_db_zonemaster_backend_ver_8.0.0.pl
```


### MySQL (or MariaDB)

Run
```sh
cd $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')
perl patch/patch_mysql_db_zonemaster_backend_ver_8.0.0.pl
```


### PostgreSQL

Run
```sh
cd $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')
perl patch/patch_postgresql_db_zonemaster_backend_ver_8.0.0.pl
```
