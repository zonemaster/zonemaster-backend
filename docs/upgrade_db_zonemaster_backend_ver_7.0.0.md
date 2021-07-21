If your zonemaster database was created by a Zonemaster-Backend version smaller
than v7.0.0, and not upgraded, use the instructions in this file.

### FreeBSD

If the installation is on FreeBSD, then set the environment before running any
of the commands below:

```sh
export ZONEMASTER_BACKEND_CONFIG_FILE="/usr/local/etc/zonemaster/backend_config.ini"
```

### SQLite

No patching (upgrading) is needed on zonemaster database on SQLite for this
version of Zonemaster-Backend.


### MySQL (or MariaDB)

No patching (upgrading) is needed on zonemaster database on MySQL (or MariaDB)
for this version of Zonemaster-Backend.


### PostgreSQL

Run
```sh
cd $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')
perl patch_postgresql_db_zonemaster_backend_ver_7.0.0.pl
```

