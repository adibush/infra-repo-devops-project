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

## Demo Secrets & Security

The Kubernetes Secrets in this repository are demo configuration only. The included MongoDB username/password and MongoDB replica-set keyfile are demo credentials used only to run this portfolio project locally. They are not personal credentials and are not connected to any production system, cloud account, GitHub account, Docker registry, or external service.

These demo values are intentionally included so the project can be cloned, deployed, and tested more easily. Kubernetes Secrets and base64 encoding should not be considered secure secret storage for production. In a real production environment, manage credentials with a dedicated secret-management solution such as External Secrets, Sealed Secrets, HashiCorp Vault, AWS Secrets Manager, or another cloud secret manager, and replace the demo credentials before adapting this project for any real environment.

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
