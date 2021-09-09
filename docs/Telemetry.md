# Telemetry

## Metrics

If [enabled][metrics feature], Statsd compatible metrics are available to use:

| Name                                           | Type    |
| ---------------------------------------------- | ------- |
| zonemaster.rpcapi.requests.\<METHOD>.\<STATUS> | Counter |
| zonemaster.testagent.tests_started             | Counter |
| zonemaster.testagent.tests_completed           | Counter |
| zonemaster.testagent.tests_died                | Counter |
| zonemaster.testagent.tests_duration_seconds    | Timing  |
| zonemaster.testagent.running_processes         | Gauge   |
| zonemaster.testagent.maximum_processes         | Gauge   |


[metrics feature]: Installation.md#d1-metrics
