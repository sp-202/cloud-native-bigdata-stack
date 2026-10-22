# IIoT Sub-chart

DCS data path, all in the release namespace:

```
DCS ──MQTT bridge──▶ Mosquitto ──▶ telegraf-kafka ──▶ Kafka topic dcs.raw ──▶ Spark (Structured Streaming)
       (:1883 via       (auth,    └▶ telegraf-vm ────▶ VictoriaMetrics (7d)  ──▶ Grafana
        Traefik TCP)    persistent)
```

| Component | Kind | Notes |
| --- | --- | --- |
| Mosquitto | StatefulSet (1) | `mqtt://<node-ip>:1883` through Traefik's `mqtt` TCP entrypoint. Users/passwords from Secret `mosquitto-credentials` (bootstrap-platform.sh). Optional outbound bridge to the DCS broker (`iiot.mosquitto.bridge`). |
| telegraf-kafka | Deployment | `mqtt_consumer` (QoS 1, persistent session) -> `outputs.kafka`, key = MQTT topic. |
| telegraf-vm | Deployment | Same input, own MQTT session -> VictoriaMetrics (Influx line protocol). Independent of Kafka: one sink being down never blocks the other. |
| Kafka | Strimzi `Kafka` + `KafkaNodePool` | 3 combined controller+broker nodes (KRaft), RF 3, min ISR 2. Bootstrap `iiot-kafka-bootstrap:9092` (plain, in-cluster). |
| `dcs.raw` | `KafkaTopic` | Raw DCS stream for Spark. |
| VictoriaMetrics | StatefulSet (1) | `-retentionPeriod=7d`, Prometheus-compatible query API on :8428 (Grafana datasource `VictoriaMetrics`), UI at `victoriametrics.<domain>/vmui`. |

Payload parsing is `iiot.telegraf.parser` (raw Telegraf TOML) — default: one numeric value per topic.
