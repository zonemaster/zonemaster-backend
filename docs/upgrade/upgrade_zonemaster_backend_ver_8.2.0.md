# Upgrade to 8.2.0

## Upgrading the database

If your Zonemaster database was created by a Zonemaster-Backend version smaller
than v8.2.0, and not upgraded, use the following instruction.

> You may need to run the command with root privileges.

```sh
cd `perl -MFile::ShareDir -le 'print File::ShareDir::dist_dir("Zonemaster-Backend")'`
perl patch/patch_db_zonemaster_backend_ver_8.2.0.pl
```
