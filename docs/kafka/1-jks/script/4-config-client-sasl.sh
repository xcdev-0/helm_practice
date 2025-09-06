kubectl run my-kafka-client --restart='Never' \
  --image docker.io/bitnami/kafka:4.0.0-debian-12-r7 \
  -n kafka --command -- sleep infinity

# # Deployment로 생성 (더 안정적)
# kubectl create deployment my-kafka-client \
#   --image=bitnami/kafka:4.0.0-debian-12-r7 \
#   -- sleep infinity

kubectl wait --for=condition=Ready pod/my-kafka-client -n kafka --timeout=120s


PW=$(kubectl get secret  kafka-sasl-passwords -n kafka \
  -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)
TRUSTSTORE_PW=$(kubectl get secret -n kafka kafka-jks-passwords \
  -o jsonpath='{.data.truststore-password}' | base64 -d | cut -d , -f 1)

cat > client.properties <<EOF
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="user1" password="${PW}";
ssl.truststore.type=JKS
ssl.truststore.location=/tmp/kafka.truststore.jks
ssl.truststore.password=${TRUSTSTORE_PW}
EOF

kubectl cp -n kafka ./client.properties my-kafka-client:/tmp/client.properties
kubectl cp -n kafka truststore/kafka.truststore.jks my-kafka-client:/tmp/kafka.truststore.jks

exit 0

### pod안에서

# 1) 토픽 생성 (브로커 수 모르면 RF=1)
kafka-topics.sh \
  --bootstrap-server my-kafka.kafka.svc.cluster.local:9092 \
  --command-config /tmp/client.properties \
  --create --topic test --partitions 1 --replication-factor 1

# 2) 목록 확인
kafka-topics.sh \
  --bootstrap-server my-kafka.kafka.svc.cluster.local:9092 \
  --command-config /tmp/client.properties \
  --list

kafka-topics.sh \
  --bootstrap-server my-kafka-controller-0.my-kafka-controller-headless.kafka.svc.cluster.local:9092 \
  --command-config /tmp/client.properties \
  --list 

# 3) 프로듀서로 몇 줄 보내기
printf 'hello\nfrom\nproducer\n' | kafka-console-producer.sh \
  --producer.config /tmp/client.properties \
  --bootstrap-server my-kafka.kafka.svc.cluster.local:9092 \
  --topic message.broadcast

kafka-console-consumer.sh \
  --consumer.config /tmp/client.properties \
  --bootstrap-server my-kafka.kafka.svc.cluster.local:9092 \
  --topic message.broadcast \
  --group chat-broadcast-server1 \
  --max-messages 1 --from-beginning

  
kafka-topics.sh \
  --bootstrap-server my-kafka-controller-0.my-kafka-controller-headless.default.svc.cluster.local:9092 \
  --command-config /tmp/client.properties \
  --list

kafka-topics.sh \
  --command-config /tmp/client.properties \
  --bootstrap-server my-kafka.kafka.svc.cluster.local:9092 \
  --list



printf 'hello\nfrom\nproducer\n' | kafka-console-producer.sh \
  --producer.config /tmp/client.properties \
  --bootstrap-server my-kafka.kafka.svc.cluster.local:9092 \
  --topic test

kafka-console-consumer.sh \
  --consumer.config /tmp/client.properties \
  --bootstrap-server my-kafka.kafka.svc.cluster.local:9092 \
  --topic test \
  --group chat-broadcast-server1 \
  --max-messages 1 --from-beginning