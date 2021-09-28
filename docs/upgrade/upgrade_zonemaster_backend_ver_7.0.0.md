If your zonemaster database was created by a Zonemaster-Backend version smaller
than v7.0.0, and not upgraded, use the instructions in this file.

### SQLite

Run
```sh
cd $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')
perl patch_sqlite_db_zonemaster_backend_ver_7.0.0.pl
```


### MySQL (or MariaDB)

Run
```sh
cd $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')
perl patch_mysql_db_zonemaster_backend_ver_7.0.0.pl
```


### PostgreSQL

Run
```sh
cd $(perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")')
perl patch_postgresql_db_zonemaster_backend_ver_7.0.0.pl
```
