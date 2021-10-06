# Upgrade to 8.0.0

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


## Upgrading the database

If your Zonemaster database was created by a Zonemaster-Backend version smaller
than v8.0.0, and not upgraded, use the following instructions.

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
