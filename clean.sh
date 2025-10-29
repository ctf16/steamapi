#!/bin/sh

# Cleanup script
# 1. Kill the cluster
# [X. Remove docker images?]
# 2. Remove tls.crt and tls.key
# 3. Remove debug/

# Kill
./scripts/k3d_kill.sh

# tls.crt, tls.key
echo "----- Removing TLS certificate and key -----"
rm tls.*

# debug/
echo "----- Removing debug directory -----"
rm -rf debug/

echo "----- Cleanup script complete -----"
