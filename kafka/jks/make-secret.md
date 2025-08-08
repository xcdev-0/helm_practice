
```
kubectl create secret generic kafka-0-jks \
  --from-file=keystore.jks=./kaka-0/keystore/kafka-0.keystore.jks \
  --from-file=truststore.jks=./kaka-0/truststore/kafka.truststore.jks

kubectl create secret generic kafka-1-jks \
  --from-file=keystore.jks=./kafka-1/keystore/kafka-1.keystore.jks \
  --from-file=truststore.jks=./kaka-0/truststore/kafka.truststore.jks
```

나중에...

extraVolumes:
  - name: kafka-0-jks
    secret:
      secretName: kafka-0-jks

extraVolumeMounts:
  - name: kafka-0-jks
    mountPath: /opt/bitnami/kafka/config/certs
    readOnly: true

config:
  kafkaSslEnabledProtocols: "TLSv1.2"
  kafkaSslTruststoreLocation: "/opt/bitnami/kafka/config/certs/truststore.jks"
  kafkaSslTruststorePassword: "storepassword"
  kafkaSslKeystoreLocation: "/opt/bitnami/kafka/config/certs/keystore.jks"
  kafkaSslKeystorePassword: "storepassword"
