To upgrade Zonemaster-Backend from versions 4.0.x to versions 5.0.x you have to upgrade the database.

### FreeBSD

If the installation is on FreeBSD, then set the environment before running any
of the commands below:

```sh
export ZONEMASTER_BACKEND_CONFIG_FILE="/usr/local/etc/zonemaster/backend_config.ini"
```

### MySQL (or MariaDB)

Run `/usr/local/bin/patch_db_mysql_for_backend_DB_version_lower_than_5.0.0.pl`


### PostgreSQL

Run `/usr/local/bin/patch_db_postgresq_for_backend_DB_version_lower_than_5.0.0.pl`

