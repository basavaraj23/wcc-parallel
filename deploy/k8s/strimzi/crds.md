# Strimzi Kafka CRDs (v0.45.0)

Applying the Strimzi manifest installs the following CustomResourceDefinitions:

- kafkas.kafka.strimzi.io
- kafkaconnects.kafka.strimzi.io
- kafkaconnectors.kafka.strimzi.io
- kafkamirrormakers.kafka.strimzi.io
- kafkamirrormaker2s.kafka.strimzi.io
- kafkatopics.kafka.strimzi.io
- kafkausers.kafka.strimzi.io
- kafkabridges.kafka.strimzi.io
- kafkanodepools.kafka.strimzi.io
- kafkarebalances.kafka.strimzi.io
- strimzipodsets.core.strimzi.io

Use `kubectl get crds | grep strimzi` to confirm they are installed.
