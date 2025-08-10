#!/usr/bin/env bash

TRUST=truststore/kafka.truststore.jks
KEY=keystore/kafka.keystore.jks
NS=default  

kubectl create secret generic kafka-jks \
  --from-file=kafka.truststore.jks="$TRUST" \
  --from-file=kafka.keystore.jks="$KEY" \
  -n "$NS"
