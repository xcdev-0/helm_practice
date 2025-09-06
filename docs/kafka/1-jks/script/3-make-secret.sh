#!/usr/bin/env bash

NS=kafka  

 kubectl create secret generic kafka-sasl-passwords \
  --from-literal=client-passwords=user1password \
  -n "$NS"


## truststore, keystore 파일을 가지는 시크릿 객체 생성
## @param tls.existingSecret Name of the existing secret containing the TLS certificates for the Kafka nodes.
## When using 'jks' format for certificates, each secret should contain a truststore and a keystore.
## Create these secrets following the steps below:
## 1) Generate your truststore and keystore files. Helpful script: https://raw.githubusercontent.com/confluentinc/confluent-platform-security-tools/master/kafka-generate-ssl.sh
## 2) Rename your truststore to `kafka.truststore.jks`.
## 3) Rename your keystores to `kafka-<role>-X.keystore.jks` where X is the replica number of the .
## 4) Run the command below one time per broker to create its associated secret (SECRET_NAME_X is the name of the secret you want to create):
##      kubectl create secret generic SECRET_NAME_0 --from-file=kafka.truststore.jks=./kafka.truststore.jks \
##        --from-file=kafka-controller-0.keystore.jks=./kafka-controller-0.keystore.jks --from-file=kafka-broker-0.keystore.jks=./kafka-broker-0.keystore.jks ...
##
## NOTE: Alternatively, a single keystore can be provided for all nodes under the key 'kafka.keystore.jks', this keystore will be used by all nodes unless overridden by the 'kafka-<role>-X.keystore.jks' file
TRUST=truststore/kafka.truststore.jks
KEY=keystore/kafka.keystore.jks

kubectl create secret generic kafka-jks \
  --from-file=kafka.truststore.jks="$TRUST" \
  --from-file=kafka.keystore.jks="$KEY" \
  -n "$NS"



 kubectl create secret generic kafka-jks-passwords \
  --from-literal=keystore-password=thisiskeystorepassword \
  --from-literal=truststore-password=thisistruststorepassword \
  -n "$NS"

kubectl create configmap  kafka-truststore \
  --from-file=kafka.truststore.jks=truststore/kafka.truststore.jks \
  -n app
