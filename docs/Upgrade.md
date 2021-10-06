# Upgrade

## 1. Overview

This document contains pointer to instructions on how to upgrade the
Zonemaster::Backend component. An upgrade usually consist of an upgrade script
to upgrade the database, and instructions to install new dependencies.


## 2. Upgrading Zonemaster::Backend

To upgrade Zonemaster::Backend perform the following tasks:

  1. stop the `zm-rpcapi` and `zm-testagent` daemons
  2. install the latest version from `cpanm` with `cpanm Zonemaster::Backend`
  3. apply any instructions specific to this new release
  4. start the `zm-rpcapi` and `zm-testagent` daemons


### Specific upgrade instructions

> Always make a backup of the database before upgrading it.

When upgrading Zonemaster::Backend, it might be needed to upgrade the database
and/or install new dependencies. Such instructions are available in the upgrade
document coming with the release. See table below to refer to the right
document.

When upgrading from an older version than the previous release, apply each
upgrade instructions one after another.

Current Zonemaster::Backend version | Link to instructions | Comments
------------------------------------|----------------------|-----------------------
 version < 1.0.3                    | [Upgrade to 1.0.3]   |
 1.0.3 ≤ version < 1.1.0            | [Upgrade to 1.1.0]   |
 1.1.0 ≤ version < 5.0.0            | [Upgrade to 5.0.0]   |
 5.0.0 ≤ version < 5.0.2            | [Upgrade to 5.0.2]   | For MySQL/MariaDB only
 5.0.2 ≤ version < 8.0.0            | [Upgrade to 8.0.0]   |


[Upgrade to 1.0.3]:  upgrade/upgrade_zonemaster_backend_ver_1.0.3.md
[Upgrade to 1.1.0]:  upgrade/upgrade_zonemaster_backend_ver_1.1.0.md
[Upgrade to 5.0.0]:  upgrade/upgrade_zonemaster_backend_ver_5.0.0.md
[Upgrade to 5.0.2]:  upgrade/upgrade_zonemaster_backend_ver_5.0.2.md
[Upgrade to 8.0.0]:  upgrade/upgrade_zonemaster_backend_ver_8.0.0.md
