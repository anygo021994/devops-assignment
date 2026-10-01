#!/bin/bash
set -euxo pipefail

# Join the k3s cluster. Retry until the control plane API is reachable.
for i in $(seq 1 30); do
  curl -sfL https://get.k3s.io | K3S_URL="https://${cp_ip}:6443" K3S_TOKEN="${k3s_token}" sh - && break
  sleep 10
done
