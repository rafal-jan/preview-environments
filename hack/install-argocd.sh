#!/bin/bash

set -em

echo "Adding Argo Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm

echo "Installing Argo CD..."
ARGOCD_NAMESPACE="argocd"
helm upgrade --install argocd argo/argo-cd \
  --namespace "$ARGOCD_NAMESPACE" \
  --create-namespace \
  --values $( dirname ${BASH_SOURCE[0]} )/../argocd-values.yaml \
  --wait

echo "Starting port forwarding..."
kubectl port-forward service/argocd-server 8443:443 \
  --namespace "$ARGOCD_NAMESPACE" &

until nc -z localhost 8443; do
    echo "Waiting for Argo CD to be accessible..."
    sleep 1
done

echo "Creating Kubernetes Secret for Crossplane Provider for Argo CD..."
ARGOCD_ADMIN_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
  --namespace "$ARGOCD_NAMESPACE" \
  --output jsonpath="{.data.password}" | base64 --decode)
ARGOCD_ADMIN_TOKEN=$(curl --silent --request POST --insecure \
  --header "Content-Type: application/json" \
  --data '{"username":"admin","password":"'$ARGOCD_ADMIN_PASSWORD'"}' \
  https://localhost:8443/api/v1/session | jq --raw-output .token)
if [ -z "$ARGOCD_ADMIN_TOKEN" ]; then
  echo "Failed to retrieve Argo CD admin token. Exiting."
  exit 1
fi
ARGOCD_PROVIDER_USER="provider-argocd"
ARGOCD_TOKEN=$(curl --silent --request POST --insecure \
  --header "Authorization: Bearer $ARGOCD_ADMIN_TOKEN" \
  --header "Content-Type: application/json" \
  https://localhost:8443/api/v1/account/$ARGOCD_PROVIDER_USER/token | jq --raw-output .token)
if [ -z "$ARGOCD_TOKEN" ]; then
  echo "Failed to retrieve Argo CD provider token. Exiting."
  exit 1
fi
kubectl create secret generic crossplane-provider-credentials \
  --namespace "$ARGOCD_NAMESPACE" \
  --from-literal=authToken="$ARGOCD_TOKEN"

echo "Argo CD URL: https://localhost:8443"
echo "Argo CD admin password: $ARGOCD_ADMIN_PASSWORD"

fg