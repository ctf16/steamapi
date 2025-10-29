#!/bin/bash

echo "Starting up the MiniCloud k3d development cluster under steamapi"
echo "Servers: 1"
echo "Agents: 1"

docker build -q -t steamuserapi-frontend:latest frontend/
docker build -q -t steamuserapi-api:latest api/

k3d cluster create steamapi --servers 1 --agents 1 -p "8080:80@loadbalancer" -p "443:443@loadbalancer" --k3s-arg "--disable=traefik@server:*"
# echo "steamapi cluster successfully initialized."

kubectl create namespace steamuserapi
# echo "SteamUserAPI namespace created."

k3d image import steamuserapi-frontend:latest -c steamapi >/dev/null
k3d image import steamuserapi-api:latest -c steamapi >/dev/null

# install Nginx Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo update >/dev/null
helm install nginx-ingress ingress-nginx/ingress-nginx --namespace steamuserapi \
     --set controller.publishService.enabled=true >/dev/null 

# generate TLS certificate and secret
openssl req -x509 \
        -new -subj "/CN=localhost" \
        -newkey rsa:4096 \
        -days 365 \
        -noenc -nodes \
        -provider default \
        -provider oqsprovider \
        -out tls.crt \
        -keyout tls.key

kubectl create secret tls nginx-secret \
	--cert=tls.crt \
	--key=tls.key \
	-n steamuserapi

echo "Waiting for Nginx ingress to be ready..."
kubectl wait --for=condition=Ready pod -n steamuserapi --selector=app.kubernetes.io/component=controller --timeout=60s

kubectl apply -f manifest/ -n steamuserapi

# debug
# kubectl get pods -n steamuserapi
# kubectl get svc -n steamuserapi
# kubectl get ingress -n steamuserapi

# wait for pods to be ready...
# echo "Waiting for frontend pod to be ready..."
# kubectl wait --for=condition=Ready pod -l app=frontend -n steamuserapi --timeout=60s
# kubectl wait --for=condition=Ready pod -l app=api -n steamuserapi --timeout=60s

# get pod names just in case
# APIPOD=$(kubectl get pods -n steamuserapi -o name | grep "api" | cut -d'/' -f2)
# FRONTENDPOD=$(kubectl get pods -n steamuserapi -o name | grep "frontend" | cut -d'/' -f2)

echo "SteamUserAPI successfully initialized!"
echo "Query the cluster at the following URL:"
echo "		http://localhost:8080/api/steamuser?steamid=STEAMID"
echo "		-H 'X-API-Key: APIKEY' https://localhost/api/steamuser?steamid=STEAMID"
echo "where STEAMID is the desired user's vanity URL"
echo "and APIKEY is your Steam Web API key (https://steamcommunity.com/dev/apikey)"

