If your zonemaster database was created by a Zonemaster-Backend version smaller
than v7.0.0, and not upgraded, use the instructions in this file.


## Database upgrade


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


## New dependencies

With this new release, we are dropping MySQL to fully use MariaDB. This applies
to the driver as well, [`DBD::mysql`] is replaced by [`DBD::MariaDB`].

### FreeBSD

First stop the `mysql-server`.
```sh
service mysql-server stop
```

Then install the new MariaDB server:
```sh
pkg install mariadb105-server p5-DBD-MariaDB
```

When asked to remove the old MySQL server (`mysql57-server`) and driver
(`p5-DBD-mysql`), do so.

Start the server (yes, it is called _mysql_) and check that it is properly
running:
```sh
service mysql-server start
service mysql-server status
```

### Debian / Ubuntu

Install the new packages with the following command:
```sh
sudo apt-get install libdbd-mariadb
```

### Centos

Install the new packages with the following command:
```sh
sudo cpanm DBD::MariaDB
```


[DBD::MariaDB]:         https://metacpan.org/pod/DBD::MariaDB
[DBD::mysql]:           https://metacpan.org/pod/DBD::mysql
