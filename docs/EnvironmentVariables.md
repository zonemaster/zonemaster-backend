# Environment variables

The PSGI server (`zonemaster_backend_rpcapi.psgi`) support the following
environment variables.

* `ZM_BACKEND_RPCAPI_LOGLEVEL`: Configure the log level, `trace` by default.
  Accepted values are:
  * `trace`
  * `debug`
  * `info` (also accepted: `inform`)
  * `notice`
  * `warning` (also accepted: `warn`)
  * `error` (also accepted: `err`)
  * `critical` (also accepted: `crit`, `fatal`)
  * `alert`
  * `emergency`
* `ZM_BACKEND_RPCAPI_LOGJSON`: Setting it to any thruthy value (non-empty
  string or non-zero number) will configure the logger to log in JSON format,
  undefined by default.
