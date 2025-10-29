# SteamUser API + Nginx Ingress controller

A simple k3s cluster that locally hosts a simple Steam API interface that fetches the public `ISteamUser` data defined in the [Steam API docs](https://developer.valvesoftware.com/wiki/Steam_Web_API#GetPlayerSummaries_(v0002)). The user provides a desired Steam user's vanity URL as displayed in their Steam community profile URL. It uses the ['k3d'](https://k3d.io/stable/) wrapper over the `k3s` Docker Hub image to host the cluster, and Python's Flask framework to host the API inside of the `steamuserapi-frontend` container. 

## Prerequisites

This project expects you to already have the following installed:
- [k3d](https://k3d.io/stable/#releases)
- [Docker Desktop + CLI](https://www.docker.com/products/docker-desktop/)
- [`curl`](https://curl.se/docs/install.html)
- OpenSSL
- [Wireshark](https://www.wireshark.org/#download)

## Usage

To run the automated validation and testing script, you must be in the `pq-readiness/api_security/k3d-api-nginx-ingress` directory. 

The `autotest.sh` script automates starting the cluster and doing some basic tests over both HTTP (port 80) and HTTPS (port 443), as well as basic validation to ensure the proper certificate is being used by the ingress controller. It also provides some instructions on how to inspect the TLS handshake packets using Wireshark, with automated packet capture for a single HTTPS query handled by the script. 

Due to the nature of capturing packets on port 443 (HTTPS), the script must be run as root. 

### Automated Script

The script takes one parameter, your Steam Web API key. If you have a Steam account, a Steam Web API key can be generated [here](https://steamcommunity.com/dev/apikey). 

```
$ pwd
.../pq-readiness/api_security/k3d-api-nginx-ingress
$ sudo ./autotest.sh "APIKEY"
```

This will create a new `debug/` directory, where the script generates the `openssl.pcap` and `openssl_handshake.txt` files. The `openssl_handshake.txt` file contains the output of an OpenSSL `s_client -connect` command, and it only referenced if the certificate subject is invalid. The `openssl.pcap` file contains the captured packets from a single OpenSSL `s_client -connect` query, which can then be viewed in a network traffic analysis program, such as Wireshark. It shows the packets containing the TLS handshake (Client Hello, Server Hello). The capture proves that the client and server agree on X25519MLKEM768 for the `key_share` extension. 

### Wireshark packet inspection

To open the `openssl.pcap` file in Wireshark, open Wireshark and go to `File -> Open` and select the `openssl.pcap`. Once the capture file is open, go to the filter search bar and type `tls.handshake` and press Enter. 

### Cleanup

To clean up, I provide a `clean.sh` script that does a handful of things:
- Kills the cluster
- Removes `tls.crt` and `tls.key`
- Removes `debug/`

It must be run as root, since the files created by the startup were created as root (`tls.crt`, `tls.key`, `debug/*`).

```
$ sudo ./clean.sh
```

## Advanced Usage

The `scripts/` directory contains two scripts that can be used for more involved usage of the API. The `k3d_startup.sh` script starts the cluster and returns you to the command line. This allows you to run multiple queries of the cluster, as well as run debugging processes. The `k3d_kill.sh` script is less of a script and more of an alias to kill the 'steamapi' cluster, but it is useful to kill the cluster before rebuilding and reinitializing it.  

Once the cluster is set up and running (i.e. `k3d_startup.sh` runs with no errors and returns you to the command line), you can query the api with whatever URL data transfer tool you prefer (this example uses [`curl`](https://github.com/curl/curl)).

The following format is required to fetch `ISteamUser` data. 

```
# curl commands
$ curl -v -H "X-API-Key: APIKEY" "http://localhost:8080/api/steamuser?steamid=STEAMID"
$ curl -vk -H "X-API-Key: APIKEY" "https://localhost/api/steamuser?steamid=STEAMID"

# openssl commands (assuming OpenSSL is installed on your local machine)
$ openssl s_client -connect localhost:443 -servername localhost -tls1_3 -groups X25519MLKEM768
```

where `STEAMID` is the desired user's Steam vanity URL, which is found at the end of someone's Steam community profile URL, and `APIKEY` is your Steam Web API key.

```
steamcommunity.com/id/VANITYURL/
```

## Traffic Analysis

With the cluster running on your local machine, you can snoop on traffic coming in and out of specific ports (80 or 443 in this case) using the `tcpdump` command. 

In whatever directory you like, you can start the `tcpdump` with the following command.

```
$ tcpdump -i any -w /path/to/tcpdump.pcap port XXXXX
```

Then, in another shell, run any of the commands in the **Advanced Usage** section above targeting the specified port. Once done running commands, end the `tcpdump` with `Ctrl+C`, and open the `.pcap` file in your favorite packet capture application.  
