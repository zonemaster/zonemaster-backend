If your zonemaster database was created by a Zonemaster-Backend version smaller than
v5.0.0, and not upgraded, use the instructions in this file.

## Database upgrade

### FreeBSD

If the installation is on FreeBSD, then set the environment before running any
of the commands below:

```sh
export ZONEMASTER_BACKEND_CONFIG_FILE="/usr/local/etc/zonemaster/backend_config.ini"
```

### MySQL (or MariaDB)

Run
```sh
cd $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')
perl patch_mysql_db_zonemaster_backend_ver_5.0.0.pl
```


### PostgreSQL

Run
```sh
cd $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')
perl patch_postgresql_db_zonemaster_backend_ver_5.0.0.pl
```




