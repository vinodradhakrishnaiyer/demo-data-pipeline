FROM docker.elastic.co/logstash/logstash-oss:8.13.2

RUN rm -f /usr/share/logstash/pipeline/logstash.conf && \
  bin/logstash-plugin install logstash-output-opensearch
