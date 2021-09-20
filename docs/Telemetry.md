# Telemetry

## Metrics

If [enabled][metrics feature], [Statsd][statsd] compatible metrics are available to use:

| Name                                           | Type    | Description |
| ---------------------------------------------- | ------- | ----------- |
| zonemaster.rpcapi.requests.\<METHOD>.\<STATUS> | Counter | Number of times the JSON RPC method \<METHOD> resulted in JSON RPC status \<STATUS>. The status is represented in string, possible values are: `RPC_PARSE_ERROR`, `RPC_INVALID_REQUEST`, `RPC_METHOD_NOT_FOUND`, `RPC_INVALID_PARAMS`, `RPC_INTERNAL_ERROR`. |
| zonemaster.testagent.tests_started             | Counter | Number of tests that have started. |
| zonemaster.testagent.tests_completed           | Counter | Number of tests that have been completed successfully. |
| zonemaster.testagent.tests_died                | Counter | Number of tests that have died. |
| zonemaster.testagent.tests_duration_seconds    | Timing  | The duration of a test, emitted for each test. |
| zonemaster.testagent.running_processes         | Gauge   | Number of running processes in a test agent. |
| zonemaster.testagent.maximum_processes         | Gauge   | Maximum number of running processes in a test agent. |


### Usage

Testing the metrics feature can be as easy as running a listening UDP server like

```sh
ns -lu 8125
```

This should be enough to see the metrics emitted by Zonemaster.

More complex setups are required for the metrics to be used in alerts and dashboards.
StatsD metrics can be integrated to a number of metrics backend like Prometheus (using the [StatsD exporter]), InfluxDB (using Telegraf and the [StatsD plugin]), Graphite ([integration guide]) and others.

[metrics feature]: Installation.md#d1-metrics
[statsd]:          https://github.com/statsd/statsd
[StatsD exporter]: https://github.com/grafana/statsd_exporter
[StatsD plugin]:   https://github.com/influxdata/telegraf/tree/master/plugins/inputs/statsd
[integration guide]: https://github.com/statsd/statsd/blob/master/docs/graphite.md
