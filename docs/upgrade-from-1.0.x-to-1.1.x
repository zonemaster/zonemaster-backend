To upgrade from versions 1.0.x to versions 1.1.x the column 'queue' needs to be added to the database:

MySQL
```
  ALTER TABLE test_results ADD queue INTEGER DEFAULT 0;
```

PostgreSQL
```
  ALTER TABLE test_results ADD queue INTEGER DEFAULT 0;
```
