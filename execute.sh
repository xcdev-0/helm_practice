#! /bin/bash
kubectl create namespace kafka
kubectl create namespace redis
kubectl create namespace mysql
kubectl create namespace app

# local test 일때만!!
minikube image load chat-frontend:newone
minikube image load chat-server:newone

# 루트 디렉토리
DIR="$(dirname "$(realpath "$0")")"

cd $DIR/docs/kafka/1-jks/script
echo "$PWD"
./1-truststore.sh
./2-keystore.sh
./3-make-secret.sh
./4-config-client-sasl.sh


cd $DIR

echo "🍀 helm install my-kafka ./kafka -n kafka"
helm install my-kafka ./kafka -n kafka

echo "🍀 helm install my-redis ./redis -n redis"
helm install my-redis ./redis -n redis

echo "🍀 helm install my-mysql ./mysql -n mysql"
helm install my-mysql ./mysql -n mysql

echo "🍀 kubectl apply -f ./app/server.yaml -n app"
kubectl apply -f ./app/server.yaml -n app

echo "🍀 kubectl apply -f ./app/frontend.yaml -n app"
kubectl apply -f ./app/frontend.yaml -n app