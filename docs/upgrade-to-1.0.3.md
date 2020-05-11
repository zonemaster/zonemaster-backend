To upgrade Zonemaster-Backend from Zonemaster-Backend versions smaller than 1.0.3 you have to upgrade the database.

### FreeBSD

If the installation is on FreeBSD, then the environment maybe has to be set before
running any of the commands below. Check where `backend_config.ini` is located.

```sh
export ZONEMASTER_BACKEND_CONFIG_FILE="/usr/local/etc/zonemaster/backend_config.ini"
```

### MySQL

Run `/usr/local/bin/patch_db_mysql_for_backend_DB_version_lower_than_1.0.3.pl`


### PostgreSQL

Run `/usr/local/bin/patch_db_postgresq_for_backend_DB_version_lower_than_1.0.3.pl`

