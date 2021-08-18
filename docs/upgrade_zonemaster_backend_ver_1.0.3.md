If your zonemaster database was created by a Zonemaster-Backend version smaller than
v1.0.3, and not upgraded, use the instructions in this file.

## Database upgrade

### FreeBSD

If the installation is on FreeBSD, then the environment maybe has to be set before
running any of the commands below. Check where `backend_config.ini` is located.

```sh
export ZONEMASTER_BACKEND_CONFIG_FILE="/usr/local/etc/zonemaster/backend_config.ini"
```

### MySQL

Run
```sh
cd $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')
perl patch_mysql_db_zonemaster_backend_ver_1.0.3.pl
```

### PostgreSQL

Run
```sh
cd $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')
perl patch_postgresql_db_zonemaster_backend_ver_1.0.3.pl
```
