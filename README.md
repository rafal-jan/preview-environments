# Preview environments

This repository is a showcase of creating isolated preview environments using ArgoCD and vCluster.

## Requirements

* An empty Kubernetes cluster

## Setting up the host cluster

### Argo CD

To install Argo CD, run the following script:

```bash
./hack/install-argocd.sh
```

### Bootstrapping the host cluster

To bootstrap the host cluster using Argo CD execute:

```bash
kubectl apply -f host-bootstrap-application.yaml
```
