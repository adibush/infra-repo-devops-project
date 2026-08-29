# Hotel DevOps Project

Kubernetes and Argo CD infrastructure for a hotel application portfolio project. This repository is the GitOps source of truth for the local Kubernetes deployment and is designed to be safe for public GitHub hosting.

## Architecture

GitHub -> GitHub Actions -> Docker images -> Argo CD -> Kubernetes -> kind port mapping -> NGINX Ingress -> Frontend / Backend -> MongoDB Replica Set

The application runs in the `hotel-project` namespace. Argo CD runs in the `argocd` namespace and deploys the frontend, backend, MongoDB, Mongo Express, services, and ingress resources from this repository.

MongoDB credentials and the replica set keyfile are created locally by `setup.sh` as Kubernetes Secrets. Real secret values are not stored in Git.

Local browser traffic reaches the cluster through direct host-to-kind port mappings: `localhost:8080` maps to container port `80`, and `localhost:8443` maps to container port `443`. This setup does not use `kubectl port-forward`.

## Technologies

- Docker
- Kubernetes
- Argo CD
- GitHub Actions
- NGINX Ingress
- MongoDB
- Mongo Express
- Git / GitHub
- kind for local Kubernetes testing

## Quick Start

```bash
git clone https://github.com/adibush/infra-repo-devops-project.git
cd infra-repo-devops-project
chmod +x setup.sh cleanup.sh
./setup.sh
```

The setup script asks for a MongoDB root username and password, creates a local kind cluster named `hotel-local`, installs Argo CD and NGINX Ingress Controller, creates the required Kubernetes Secrets, and applies the Argo CD Applications.

Open the application:

```text
http://localhost:8080/
```

## Application URLs

Frontend:

```text
http://localhost:8080/
```

Backend API:

```text
http://localhost:8080/api/
```

Mongo Express:

```text
http://localhost:8080/mongo
```

HTTPS, if configured:

```text
https://localhost:8443/
```

## Useful Commands

```bash
kubectl get pods -n hotel-project
kubectl get applications -n argocd
kubectl get ingress -n hotel-project
```

## Secrets

Only safe example Secret manifests are committed:

```text
kubernetes/secrets/mongodb-secret.example.yaml
kubernetes/secrets/mongodb-keyfile-secret.example.yaml
```

The real Kubernetes Secrets are created directly in the cluster by `setup.sh`:

```text
mongodb-secret
mongodb-keyfile-secret
```

These local secret files are ignored by Git:

```text
kubernetes/secrets/mongodb-secret.yaml
kubernetes/secrets/mongodb-keyfile-secret.yaml
kubernetes/secrets/mongodb-keyfile
```

The generated password and MongoDB keyfile contents are not printed by the setup script.

## Repositories

- Infrastructure: https://github.com/adibush/infra-repo-devops-project
- Frontend: add repository URL
- Backend: add repository URL

## Cleanup

To delete only the local kind cluster created for this project:

```bash
./cleanup.sh
```

This removes Kubernetes resources and local persistent data inside the `hotel-local` cluster.
