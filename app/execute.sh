#! /bin/bash

kubectl apply -f ./chatbot/chatbot-configmap.yaml -n app
kubectl apply -f ./chatbot/chatbot-secret.yaml -n app
kubectl apply -f ./chatbot/chatbot.yaml -n app
kubectl apply -f ./chatbot/chatbot-svc.yaml -n app

kubectl apply -f ./chat/server-configmap.yaml -n app
kubectl apply -f ./chat/server-secret.yaml -n app
kubectl apply -f ./chat/server.yaml -n app
kubectl apply -f ./chat/server-svc.yaml

kubectl apply -f ./frontend/frontend.yaml -n app
kubectl apply -f ./frontend/frontend-configmap.yaml -n app

# kubectl apply -f ./consumer.yaml -n app