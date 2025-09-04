minikube ip                                  # 예: 192.168.49.2

# 브로커별 NodePort 목록
kubectl get svc -l "app.kubernetes.io/instance=my-kafka,app.kubernetes.io/component=kafka,pod" \
  -o custom-columns=NAME:.metadata.name,PORT:.spec.ports[0].nodePort

# 각 포드의 advertised.listeners(특히 EXTERNAL) 확인
for i in 0 1 2; do
  echo "# controller-$i"
  kubectl exec -it my-kafka-controller-$i -- \
    sh -lc "grep '^advertised.listeners' /opt/bitnami/kafka/config/server.properties"
done


# 프로듀서
kafka-console-producer.sh \
  --producer.config ./client.properties \
  --bootstrap-server 192.168.49.2:32651 \
  --producer-property acks=all \
  --topic test

# 컨슈머
kafka-console-consumer.sh \
  --consumer.config ./client-external.properties \
  --bootstrap-server 192.168.49.2:<아무 브로커의 NodePort> \
  --topic test --from-beginning

