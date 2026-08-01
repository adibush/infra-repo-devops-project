# Hotel Reservation System Architecture

This diagram shows the complete DevOps flow: source code, CI pipelines, Docker images, GitOps deployment with ArgoCD, and the running Kubernetes application.

```mermaid
flowchart LR
    user["User Browser<br/>http://localhost"]

    subgraph source["GitHub Private Repositories"]
        direction TB
        frontendRepo["frontend-repo-devops-project<br/>Frontend source code"]
        backendRepo["backend-repo-devops-project<br/>Backend source code"]
        infraRepo["infra-repo-devops-project<br/>Kubernetes manifests<br/>Source of truth"]
    end

    subgraph ci["GitHub Actions CI/CD"]
        direction TB
        frontendPipeline1["Frontend Pipeline 1<br/>Build Docker image<br/>Push to Docker Hub"]
        backendPipeline1["Backend Pipeline 1<br/>Build Docker image<br/>Push to Docker Hub"]
        frontendPipeline2["Frontend Pipeline 2<br/>Update frontend image tag<br/>Open and merge PR to infra main"]
        backendPipeline2["Backend Pipeline 2<br/>Update backend image tag<br/>Open and merge PR to infra main"]
    end

    dockerHub["Docker Hub<br/>adibush/hotel-frontend<br/>adibush/hotel-backend"]

    subgraph argocd["argocd Namespace"]
        direction TB
        argocdController["ArgoCD<br/>Watches infra-repo main"]
        frontendApp["Application<br/>hotel-frontend"]
        backendApp["Application<br/>hotel-backend"]
    end

    subgraph cluster["Docker Desktop Kubernetes Cluster"]
        direction TB
        ingress["NGINX Ingress Controller<br/>Routes localhost traffic"]

        subgraph hotel["hotel-project Namespace"]
            direction TB

            subgraph appLayer["Application Layer"]
                direction LR
                frontend["Frontend Deployment<br/>5 replicas<br/>nginx"]
                backend["Backend Deployment<br/>5 replicas<br/>Flask API"]
                mongoExpress["Mongo Express<br/>Database UI"]
            end

            subgraph configLayer["Configuration"]
                direction LR
                backendConfig["ConfigMap<br/>backend-config"]
                mongodbSecret["Secret<br/>mongodb-secret"]
                keyfileSecret["Secret<br/>mongodb-keyfile-secret"]
            end

            subgraph dataLayer["Data Layer"]
                direction TB
                mongoService["MongoDB Services<br/>mongodb-service<br/>mongodb-headless-service"]

                subgraph replicaSet["MongoDB StatefulSet<br/>Replica Set rs0"]
                    direction LR
                    mongo0["mongodb-0<br/>PRIMARY"]
                    mongo1["mongodb-1<br/>SECONDARY"]
                    mongo2["mongodb-2<br/>SECONDARY"]
                end

                pvc0["PVC<br/>mongodb-data-mongodb-0"]
                pvc1["PVC<br/>mongodb-data-mongodb-1"]
                pvc2["PVC<br/>mongodb-data-mongodb-2"]
            end
        end
    end

    frontendRepo --> frontendPipeline1
    backendRepo --> backendPipeline1

    frontendPipeline1 --> dockerHub
    backendPipeline1 --> dockerHub

    frontendPipeline1 --> frontendPipeline2
    backendPipeline1 --> backendPipeline2

    frontendPipeline2 --> infraRepo
    backendPipeline2 --> infraRepo

    infraRepo --> argocdController
    argocdController --> frontendApp
    argocdController --> backendApp

    frontendApp --> frontend
    backendApp --> backend
    backendApp --> mongoExpress
    backendApp --> mongoService

    dockerHub --> frontend
    dockerHub --> backend

    user --> ingress
    ingress -->|"/"| frontend
    ingress -->|"/api"| backend
    ingress -->|"/mongo"| mongoExpress

    backend --> backendConfig
    backend --> mongodbSecret
    backend --> mongoService

    mongoExpress --> mongodbSecret
    mongoExpress --> mongoService

    mongoService --> mongo0
    mongoService --> mongo1
    mongoService --> mongo2

    keyfileSecret --> mongo0
    keyfileSecret --> mongo1
    keyfileSecret --> mongo2

    mongo0 --> pvc0
    mongo1 --> pvc1
    mongo2 --> pvc2
```

## Flow Explanation

1. Developers push frontend or backend changes to the `dev` branch.
2. Pipeline 1 builds a Docker image and pushes it to Docker Hub.
3. Pipeline 2 updates the matching Kubernetes deployment image tag in the infrastructure repository.
4. The infrastructure repository is the GitOps source of truth.
5. ArgoCD watches the `main` branch of the infrastructure repository.
6. After a change is merged to `main`, ArgoCD automatically syncs the Kubernetes cluster.
7. Users access the system through NGINX Ingress on `http://localhost`.
8. The frontend calls the backend through `/api`.
9. The backend connects to MongoDB Replica Set `rs0`.
10. Mongo Express is available through `/mongo` for database inspection.

## Important Notes

- Frontend and backend each run with 5 replicas.
- MongoDB runs as a 3-member StatefulSet.
- Each MongoDB pod has its own PVC.
- MongoDB credentials are stored in Kubernetes Secrets.
- Backend MongoDB host and database settings are stored in a ConfigMap.
- ArgoCD manages deployments from Git and keeps the cluster synchronized.
