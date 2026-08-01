# Hotel Reservation System Architecture

This file explains the project architecture in a simple way.

The project has three main parts:

- Application code: frontend and backend repositories
- Infrastructure code: Kubernetes and ArgoCD manifests
- Kubernetes cluster: the running application

## Simple DevOps Flow

```mermaid
flowchart TD
    dev["Developer pushes code to dev branch"]
    actions["GitHub Actions<br/>Build Docker image"]
    dockerhub["Docker Hub<br/>Stores frontend and backend images"]
    infra["Infrastructure Repository<br/>Kubernetes YAML files<br/>main branch"]
    argocd["ArgoCD<br/>Watches infra repository"]
    cluster["Kubernetes Cluster<br/>Runs the project"]

    dev --> actions
    actions --> dockerhub
    actions --> infra
    infra --> argocd
    argocd --> cluster
```

## Running Application

```mermaid
flowchart TD
    user["User Browser<br/>http://localhost"]
    ingress["NGINX Ingress"]

    frontend["Frontend<br/>5 replicas"]
    backend["Backend Flask API<br/>5 replicas"]
    mongoExpress["Mongo Express<br/>Database UI"]

    mongodb["MongoDB StatefulSet<br/>3 replicas<br/>Replica Set rs0"]
    pvc["Persistent Storage<br/>One PVC per MongoDB pod"]
    config["ConfigMap<br/>Backend configuration"]
    secret["Secrets<br/>MongoDB credentials"]

    user --> ingress

    ingress -->|"/"| frontend
    ingress -->|"/api"| backend
    ingress -->|"/mongo"| mongoExpress

    backend --> mongodb
    mongoExpress --> mongodb

    backend --> config
    backend --> secret
    mongoExpress --> secret

    mongodb --> pvc
```

## MongoDB Replica Set

```mermaid
flowchart LR
    backend["Backend"]

    mongo0["mongodb-0<br/>PRIMARY"]
    mongo1["mongodb-1<br/>SECONDARY"]
    mongo2["mongodb-2<br/>SECONDARY"]

    pvc0["PVC 0"]
    pvc1["PVC 1"]
    pvc2["PVC 2"]

    backend --> mongo0
    backend --> mongo1
    backend --> mongo2

    mongo0 --> pvc0
    mongo1 --> pvc1
    mongo2 --> pvc2
```

## Short Explanation

1. The developer pushes code to the `dev` branch.
2. GitHub Actions builds a Docker image.
3. The image is pushed to Docker Hub.
4. Pipeline 2 updates the Kubernetes image tag in the infrastructure repository.
5. The change is merged to the `main` branch of the infrastructure repository.
6. ArgoCD watches the infrastructure repository.
7. ArgoCD applies the Kubernetes manifests to the cluster.
8. The user accesses the application through `http://localhost`.

## Main Components

| Component | Purpose |
| --- | --- |
| Frontend | The HTML, CSS, and JavaScript user interface |
| Backend | The Flask API for hotels and reservations |
| MongoDB | Stores hotels and reservations |
| Mongo Express | Web UI for viewing MongoDB data |
| NGINX Ingress | Routes browser traffic to the correct service |
| Docker Hub | Stores Docker images |
| ArgoCD | Keeps Kubernetes synchronized with Git |
| ConfigMap | Stores non-secret backend configuration |
| Secret | Stores MongoDB username, password, and keyfile |
| PVC | Stores MongoDB data permanently |
