#!/bin/sh

build_anim() {
	printf "Building"
	while :; do
		for i in 1 2 3; do
			printf "\rBuilding"
			printf "%${i}s" | tr ' ' '.'
			sleep 1
		done
		printf "\r\033[KBuilding"
	done
}

cluster_anim() {
	printf "Creating"
	while :; do
		for i in 1 2 3; do
			printf "\rCreating"
			printf "%${i}s" | tr ' ' '.'
			sleep 1
		done
		printf "\r\033[KCreating"
	done
}

helm_anim() {
	printf "Helming"
	while :; do
		for i in 1 2 3; do
			printf "\rHelming"
			printf "%${i}s" | tr ' ' '.'
			sleep 1
		done
		printf "\r\033[KHelming"
	done
}



# Set up constant configs
# =======================
CLUSTERNAME="steamapi"
NAMESPACE="steamuserapi"
HTTP_APIURL="localhost:8080/api"
HTTPS_APIURL="https://localhost/api"

# Pull API Key from arguments
# ===========================
APIKEY=""
VERBOSE=0
STEAMID="oblivion_rl"
while getopts ":k:v:u:" opt; do
	case "$opt" in
		k)	
			APIKEY="$OPTARG"
			;;
		v)	
			VERBOSE="$OPTARG"
			;;
		u)	
			STEAMID="$OPTARG"
			;;
		\?)	
			echo "Error: Invalid option -$OPTARG" >&2
			exit 1
			;;
		:)	
			echo "Error: Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done

if [ -z $APIKEY ]; then
	echo "Error: Missing API key. Use -k <key>" >&2
	exit 1
fi

echo "--------------------------------------------------"
echo "----- Starting k3d cluster validation script -----"
echo "--------------------------------------------------"
mkdir -p debug



# List active clusters and kill steamapi if it exists
# ===================================================
echo " "
echo "--------------------------------------"
echo "----- Displaying active clusters -----"
echo "--------------------------------------"
k3d cluster list || echo "No active clusters."
if k3d cluster list | grep -q "$CLUSTERNAME"; then
	echo " "
	echo "----- Found $CLUSTERNAME cluster. Proceding with removal. -----"
	k3d cluster delete "$CLUSTERNAME"
else
	echo " "
	echo "----- $CLUSTERNAME cluster is not active. Skipping. -----"
fi
# ===================================================



# Start up a new steamapi cluster (100% QUIET)
# ============================================
echo " "
echo "-------------------------------"
echo "----- Starting up cluster -----"
echo "-------------------------------"


# Build docker images
# echo "----- Building Docker images -----"
if [ $VERBOSE -eq 1 ]; then
	docker build -t steamuserapi-frontend:latest frontend/
	docker build -t steamuserapi-api:latest api/
	echo " "
else
	build_anim & BUILDER_PID=$!
	docker build -q -t steamuserapi-frontend:latest frontend/ \
		>/dev/null
	docker build -q -t steamuserapi-api:latest api/ \
		>/dev/null
	kill "$BUILDER_PID" \
		>/dev/null 2>&1
	printf " Done!"
	echo " "
fi

# Start k3d cluster
# echo "----- Creating cluster and namespace -----"
if [ $VERBOSE -eq 1 ]; then
	k3d cluster create steamapi -s 1 -a 1 \
		-p "8080:80@loadbalancer" -p "443:443@loadbalancer" \
		--k3s-arg "--disable=traefik@server:*"
	kubectl create namespace steamuserapi

	k3d image import steamuserapi-frontend:latest -c steamapi
	k3d image import steamuserapi-api:latest -c steamapi
	echo " "
else
	cluster_anim & CLUSTERER_PID=$!
	k3d cluster create steamapi -s 1 -a 1 \
		-p "8080:80@loadbalancer" -p "443:443@loadbalancer" \
		--k3s-arg "--disable=traefik@server:*" \
		>/dev/null
	kubectl create namespace steamuserapi \
		>/dev/null

	k3d image import steamuserapi-frontend:latest -c steamapi \
		>/dev/null
	k3d image import steamuserapi-api:latest -c steamapi \
		>/dev/null
	kill "$CLUSTERER_PID" \
		>/dev/null 2>&1
	printf " Done!"
	echo " "
fi

if [ $VERBOSE -eq 1 ]; then
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo update 
	helm install nginx-ingress ingress-nginx/ingress-nginx --namespace steamuserapi \
		--set controller.publishService.enabled=true
	echo " "
else
	helm_anim & HELMER_PID=$!
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx \
		>/dev/null
	helm repo update \
		>/dev/null
	helm install nginx-ingress ingress-nginx/ingress-nginx --namespace steamuserapi \
     		--set controller.publishService.enabled=true \
		>/dev/null
	kill "$HELMER_PID" \
		>/dev/null 2>&1
	printf " Done!"
	echo " "
fi

# Generate TLS certificate and secret
echo "----- Generating TLS certificate -----"
openssl req -x509 \
        -new -subj "/CN=localhost" \
        -newkey rsa:4096 \
        -days 365 \
        -noenc -nodes \
        -provider default \
        -provider oqsprovider \
        -out tls.crt \
        -keyout tls.key
echo "Done."

echo "----- Creating TLS secret -----"
kubectl create secret tls nginx-secret \
        --cert=tls.crt \
        --key=tls.key \
        -n steamuserapi
echo "Done."

echo "----- Waiting for ingress controller pod -----"
kubectl wait --for=condition=Ready pod -n steamuserapi --selector=app.kubernetes.io/component=controller --timeout=60s
kubectl apply -f manifest/ -n steamuserapi

echo "SteamUserAPI successfully initialized!"
echo "Query the cluster at the following URL:"
echo "          http://localhost:8080/api/steamuser?steamid=STEAMID"
echo "          -H 'X-API-Key: APIKEY' https://localhost/api/steamuser?steamid=STEAMID"
echo "where STEAMID is the desired user's vanity URL,"
echo "and APIKEY is your Steam Web API key (https://steamcommunity.com/dev/apikey)"
# ============================================



# Wait for services and deployments to be ready
# =============================================
echo " "
echo "--------------------------------------------"
echo "----- Waiting for all pods to be ready -----"
echo "--------------------------------------------"
kubectl get pods -n "$NAMESPACE"
echo " "
kubectl wait --for=condition=Ready pods --all -n "$NAMESPACE" --timeout=60s
sleep 3
echo "----- All pods ready -----"
# =============================================



# Basic HTTP test
# ===============
echo " "
echo " "
echo "------------------------------------------------------------------"
echo "----- Testing simple connectivity to API over HTTP with cURL -----"
echo "------------------------------------------------------------------"
if [ $VERBOSE -eq 1 ]; then
	curl -v localhost:8080/api
else
	curl localhost:8080/api
fi


echo " "
echo " "
echo "------------------------------------------------------------"
echo "----- Testing simple API retrieval over HTTP with cURL -----"
echo "------------------------------------------------------------"
if [ $VERBOSE -eq 1 ]; then
	curl -v -H "X-API-Key: $APIKEY" "localhost:8080/api/steamuser?steamid=$STEAMID"
else
	curl -H "X-API-Key: $APIKEY" "localhost:8080/api/steamuser?steamid=$STEAMID"
fi
# ===============



# Basic HTTPS test
# ================
echo " "
echo " "
echo "------------------------------------------------------------"
echo "----- Testing connectivity to API over HTTPS with cURL -----"
echo "------------------------------------------------------------"
if [ $VERBOSE -eq 1 ]; then
	curl -vk "https://localhost/api"
else
	curl -k "https://localhost/api"
fi


echo " "
echo " "
echo "------------------------------------------------------"
echo "----- Testing API retrieval over HTTPS with cURL -----"
echo "------------------------------------------------------"
if [ $VERBOSE -eq 1 ]; then
	curl -vk -H "X-API-Key: $APIKEY" "https://localhost/api/steamuser?steamid=$STEAMID"
else
	curl -k -H "X-API-Key: $APIKEY" "https://localhost/api/steamuser?steamid=$STEAMID"
fi
# ================



# OpenSSL s_client test
# =====================
echo " "
echo " "
echo "------------------------------------------------------------"
echo "----- Testing OpenSSL 's_client' handshake negotiation -----"
echo "------------------------------------------------------------"
openssl s_client -connect localhost:443 -servername localhost -tls1_3 -groups X25519MLKEM768 </dev/null > debug/openssl_handshake.txt

echo " "
echo "----- Checking for expected certificate and KEM -----"
if grep -q "CN = localhost" debug/openssl_handshake.txt; then
	echo "Found certificate subject 'CN = localhost'. Moving on."
else 
	echo "Expected certificate subject not found. Examine debug/openssl_handshake.txt for details."
	exit 1
fi



# Capture traffic for WireShark analysis
# ======================================
echo " "
echo "---------------------------------------"
echo "----- Capturing handshake packets -----"
echo "---------------------------------------"
rm debug/openssl.pcap
tcpdump -i any -w debug/openssl.pcap port 443 & TCPDUMP_PID=$!
sleep 2
openssl s_client -connect localhost:443 -servername localhost -tls1_3 -groups X25519MLKEM768 </dev/null >/dev/null 
sleep 2
kill $TCPDUMP_PID
echo "----- Killed tcpdump -----"
sleep 1
# ======================================



# WireShark instructions
# ======================
echo " "
echo "-----------------------------"
echo "----- Packet Inspection -----"
echo "-----------------------------"
echo "To inspect the agreed-upon 'key_share' extension, open the capture file in Wireshark. The hybrid TLS handshake capture file can be found at k3d-api-nginx-ingress/debug/openssl.pcap"
echo " "
echo "----- Wireshark analysis -----"
echo "	1. Open Wireshark (or download from https://www.wireshark.org/#download)"
echo "	2. Go to File -> Open -> Choose the openssl.pcap file."
echo "	3. In the display filter search bar, type 'tls.handshake' and press Enter"
echo "	4. To find key_share details: "
echo "		4.1. In the 'Client Hello' packet, expand the" 
echo "		'Transport Layer Security -> TLSv1.3 Record Layer: Handshake Procotol -> Handshake Protocol: Client Hello'" 
echo "		field and find the 'Extension: key_share' line. It should say 'X25519MLKEM768', " 
echo "		indicating that the client is requesting a TLS handshake using the X25519MLKEM768 key exchange."
echo "		4.2. In the 'Server Hello' packet, expand the" 
echo "		'Transport Layer Security -> TLSv1.3 Record Layer: Handshake Protocol -> Handshake Protocol: Server Hello'" 
echo "		field and find the 'Extension: key_share' line. It should say 'X25519MLKEM768', "
echo "		indicating that the cluster has agreed to X25519MLKEM768 key exchange."
echo " "
# ======================



echo " "
echo "██████╗  ██████╗ ███╗   ██╗███████╗"
echo "██╔══██╗██╔═══██╗████╗  ██║██╔════╝"
echo "██║  ██║██║   ██║██╔██╗ ██║█████╗  "
echo "██║  ██║██║   ██║██║╚██╗██║██╔══╝  "
echo "██████╔╝╚██████╔╝██║ ╚████║███████╗"
echo "╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝"
echo " "
echo "Automated testing script complete."
