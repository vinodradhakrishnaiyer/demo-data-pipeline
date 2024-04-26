#/bin/bash

/opt/bitnami/kafka/bin/kafka-topics.sh --create --topic $TEST_TOPIC_NAME --partitions=2 --bootstrap-server kafka:9092
echo "topic $TEST_TOPIC_NAME was created"
