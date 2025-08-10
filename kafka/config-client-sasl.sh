PW=$(kubectl get secret my-kafka-user-passwords -n default \
  -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)

cat > client.properties <<EOF
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="user1" password="${PW}";
ssl.truststore.type=JKS
ssl.truststore.location=/tmp/kafka.truststore.jks
ssl.truststore.password=truststorepassword
EOF

kubectl cp -n default ./client.properties my-kafka-client:/tmp/client.properties
kubectl cp -n default truststore/kafka.truststore.jks my-kafka-client:/tmp/kafka.truststore.jks
