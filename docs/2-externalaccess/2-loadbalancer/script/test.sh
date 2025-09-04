
HOST="34.64.219.29:9094"

kafka-topics \
  --bootstrap-server "${HOST}" \
  --command-config ./client.properties \
  --list

kafka-console-producer \
  --producer.config ./client.properties \
  --bootstrap-server "${HOST}" \
  --topic test

