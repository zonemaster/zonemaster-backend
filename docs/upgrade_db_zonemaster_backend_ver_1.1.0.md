If your zonemaster database was created by a Zonemaster-Backend version smaller than
v1.1.0, and not upgraded, use the instructions in this file.

MySQL

```
  ALTER TABLE test_results ADD queue INTEGER DEFAULT 0;
```

PostgreSQL

```
  ALTER TABLE test_results ADD queue INTEGER DEFAULT 0;
```

