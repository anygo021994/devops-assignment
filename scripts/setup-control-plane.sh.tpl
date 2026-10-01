#!/bin/bash
set -euxo pipefail

# 1. k3s server
curl -sfL https://get.k3s.io | K3S_TOKEN="${k3s_token}" \
  INSTALL_K3S_EXEC="server --tls-san ${public_ip}" sh -

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
until kubectl get nodes >/dev/null 2>&1; do sleep 5; done

# 2. Argo CD (pinned version). --server-side is needed because some CRDs
#    are too large for client-side apply.
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

# 3. Register the application (Argo CD then syncs it from Git)
for i in $(seq 1 30); do
  kubectl apply -f \
    https://raw.githubusercontent.com/anygo021994/devops-assignment/main/argocd/application.yaml && break
  sleep 10
done
