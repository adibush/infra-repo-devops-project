# Hotel Reservation Infrastructure

Kubernetes and ArgoCD infrastructure repository for the Hotel Reservation DevOps final project.

This repository is used by ArgoCD as the GitOps source of truth.

## Technologies

- Kubernetes
- Docker Desktop Kubernetes
- NGINX Ingress Controller
- MongoDB Replica Set
- Mongo Express
- ArgoCD
- GitHub Actions

## Repository Structure

```text
infra-repo-devops-project/
|-- argocd/
|   |-- argocd-persistence.yaml
|   |-- backend-app.yaml
|   `-- frontend-app.yaml
|-- kubernetes/
|   |-- configmaps/
|   |-- deployments/
|   |-- secrets/
|   |-- services/
|   `-- statefulsets/
|-- ARCHITECTURE.md
`-- README.md
```

## Architecture Diagram

The project architecture diagram is documented in:

```text
ARCHITECTURE.md
```

## Kubernetes Namespace

Application resources are deployed to:

```text
hotel-project
```

ArgoCD resources are deployed to:

```text
argocd
```

## Kubernetes Secrets

This repository contains example Secret manifests only:

```text
kubernetes/secrets/mongodb-secret.example.yaml
kubernetes/secrets/mongodb-keyfile-secret.example.yaml
```

Real credentials must be created locally or injected securely before deployment. Do not commit real Secret manifests or credential values to Git.

For local-only manifest testing, create ignored local copies from the examples and replace the placeholder values:

```bash
cp kubernetes/secrets/mongodb-secret.example.yaml kubernetes/secrets/mongodb-secret.yaml
cp kubernetes/secrets/mongodb-keyfile-secret.example.yaml kubernetes/secrets/mongodb-keyfile-secret.yaml
```

ArgoCD does not include the real Secret filenames from Git. The workloads still expect these Secret objects to exist in the `hotel-project` namespace:

```text
mongodb-secret
mongodb-keyfile-secret
```

Create the real Secrets manually before syncing ArgoCD, or inject them through a secure secrets workflow such as Sealed Secrets, External Secrets, or a private Git source.

```bash
kubectl create namespace hotel-project --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic mongodb-secret \
  --namespace hotel-project \
  --from-literal=MONGO_INITDB_ROOT_USERNAME=YOUR_MONGO_USERNAME \
  --from-literal=MONGO_INITDB_ROOT_PASSWORD=YOUR_MONGO_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic mongodb-keyfile-secret \
  --namespace hotel-project \
  --from-literal=mongodb-keyfile=YOUR_MONGODB_KEYFILE \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl annotate secret mongodb-secret \
  --namespace hotel-project \
  argocd.argoproj.io/sync-options=Prune=false \
  argocd.argoproj.io/compare-options=IgnoreExtraneous \
  --overwrite

kubectl annotate secret mongodb-keyfile-secret \
  --namespace hotel-project \
  argocd.argoproj.io/sync-options=Prune=false \
  argocd.argoproj.io/compare-options=IgnoreExtraneous \
  --overwrite
```

The `Prune=false` annotation protects the manually-created Secrets if they were previously managed by ArgoCD and automated pruning is enabled. The `IgnoreExtraneous` annotation prevents those manual Secrets from making the ArgoCD application appear out of sync solely because they are not in Git.

The backend ArgoCD Application also sets `Prune=false` as an application sync option so removing the old Secret manifests from Git does not cause an automated prune of the live Secrets. Automated self-heal remains enabled for the resources that are still managed from Git.

## Main Components

| Component | Description |
| --- | --- |
| Frontend | Static HTML/CSS/JavaScript served by NGINX |
| Backend | Flask API connected to MongoDB |
| MongoDB | 3-member Replica Set using StatefulSet |
| Mongo Express | Web UI for MongoDB |
| NGINX Ingress | Routes traffic to frontend, backend, and Mongo Express |
| ArgoCD | Automatically syncs Kubernetes manifests from Git |

## MongoDB

MongoDB runs as a StatefulSet with 3 Pods:

```text
mongodb-0
mongodb-1
mongodb-2
```

Replica Set name:

```text
rs0
```

Each MongoDB Pod has its own PVC created by the StatefulSet `volumeClaimTemplates`.

The project does not need a separate `kubernetes/volumes` directory because the MongoDB PVCs are generated automatically by:

```text
kubernetes/statefulsets/mongodb-statefulset.yaml
```

## Ingress Routes

| Path | Service |
| --- | --- |
| `/` | Frontend |
| `/api` | Backend |
| `/mongo` | Mongo Express |

## ArgoCD Applications

| Application | Manifest |
| --- | --- |
| `hotel-backend` | `argocd/backend-app.yaml` |
| `hotel-frontend` | `argocd/frontend-app.yaml` |

Both applications use:

- Automated Sync
- Self Heal
- Prune

Target branch:

```text
main
```

## Apply ArgoCD Applications

```bash
kubectl apply -f argocd/backend-app.yaml
kubectl apply -f argocd/frontend-app.yaml
```

## Useful Verification Commands

```bash
kubectl get applications -n argocd
kubectl get pods -n hotel-project
kubectl get svc -n hotel-project
kubectl get ingress -n hotel-project
kubectl get pvc -n hotel-project
```

## Access Application

Frontend:

```text
http://localhost
```

Backend hotels API:

```text
http://localhost/api/hotels
```

Mongo Express:

```text
http://localhost/mongo
```

## GitOps Flow

1. Backend or frontend code is pushed to the `dev` branch.
2. Pipeline 1 builds and pushes a Docker image to Docker Hub.
3. Pipeline 2 updates the matching Kubernetes Deployment image tag in this repository.
4. Pipeline 2 opens and merges a pull request from `dev` to `main`.
5. ArgoCD detects the change on `main`.
6. ArgoCD syncs the updated Kubernetes manifests automatically.
