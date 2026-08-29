#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-hotel-local}"
APP_NAMESPACE="${APP_NAMESPACE:-hotel-project}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
INGRESS_NGINX_VERSION="${INGRESS_NGINX_VERSION:-controller-v1.12.1}"
INGRESS_NGINX_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_NGINX_VERSION}/deploy/static/provider/kind/deploy.yaml"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '\n==> %s\n' "$1"
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required tool: %s\n' "$1" >&2
    exit 1
  fi
}

port_in_use() {
  local port="$1"

  netstat -ano -p tcp 2>/dev/null | awk -v port="$port" '
    $1 ~ /^TCP/ && $4 == "LISTENING" && $2 ~ (":" port "$") {
      found = 1
    }
    END {
      exit found ? 0 : 1
    }
  '
}

check_host_ports() {
  local port

  require_tool netstat

  for port in 8080 8443; do
    if port_in_use "$port"; then
      printf 'ERROR: Port %s is already in use.\n' "$port" >&2
      printf 'Close the process using this port or choose another host port.\n' >&2
      exit 1
    fi
  done
}

wait_for_argocd() {
  kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-applicationset-controller --timeout=300s
  kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-dex-server --timeout=300s
  kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-notifications-controller --timeout=300s
  kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-redis --timeout=300s
  kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-repo-server --timeout=300s
  kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-server --timeout=300s
  kubectl -n "$ARGOCD_NAMESPACE" rollout status statefulset/argocd-application-controller --timeout=300s
}

read_secret() {
  local prompt="$1"
  local value
  read -r -s -p "$prompt" value
  printf '\n' >&2
  if [ -z "$value" ]; then
    printf 'Value cannot be empty.\n' >&2
    exit 1
  fi
  printf '%s' "$value"
}

log "Checking required tools"
for tool in docker kubectl kind openssl; do
  require_tool "$tool"
done

log "Checking Docker"
docker info >/dev/null

log "Creating or reusing kind cluster: ${CLUSTER_NAME}"
if kind get clusters | grep -Fxq "$CLUSTER_NAME"; then
  printf 'Cluster %s already exists; reusing it.\n' "$CLUSTER_NAME"
else
  log "Checking required host ports"
  check_host_ports
  kind create cluster --name "$CLUSTER_NAME" --config "$ROOT_DIR/kind-config.yaml"
fi

log "Using kubectl context: kind-${CLUSTER_NAME}"
kubectl config use-context "kind-${CLUSTER_NAME}"

log "Installing or updating Argo CD"
kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n "$ARGOCD_NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

log "Waiting for Argo CD"
wait_for_argocd

log "Installing or updating NGINX Ingress Controller for kind"
kubectl apply -f "$INGRESS_NGINX_URL"

log "Waiting for NGINX Ingress Controller"
kubectl -n ingress-nginx wait --for=condition=Ready pod \
  -l app.kubernetes.io/component=controller \
  --timeout=300s
kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=300s

log "Creating application namespace"
kubectl create namespace "$APP_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

log "Checking MongoDB Secrets"
MONGODB_SECRET_EXISTS=false
MONGODB_KEYFILE_SECRET_EXISTS=false

if kubectl -n "$APP_NAMESPACE" get secret mongodb-secret >/dev/null 2>&1; then
  MONGODB_SECRET_EXISTS=true
fi

if kubectl -n "$APP_NAMESPACE" get secret mongodb-keyfile-secret >/dev/null 2>&1; then
  MONGODB_KEYFILE_SECRET_EXISTS=true
fi

if [ "$MONGODB_SECRET_EXISTS" = true ] && [ "$MONGODB_KEYFILE_SECRET_EXISTS" = true ]; then
  echo "MongoDB Secrets already exist; reusing them."
elif [ "$MONGODB_SECRET_EXISTS" = false ] && [ "$MONGODB_KEYFILE_SECRET_EXISTS" = false ]; then
  log "Collecting MongoDB credentials"
  read -r -p "MongoDB root username: " MONGO_USERNAME
  if [ -z "$MONGO_USERNAME" ]; then
    printf 'MongoDB root username cannot be empty.\n' >&2
    exit 1
  fi
  MONGO_PASSWORD="$(read_secret 'MongoDB root password: ')"
  MONGO_KEYFILE="$(openssl rand -base64 756)"

  log "Creating Kubernetes Secrets"
  kubectl -n "$APP_NAMESPACE" create secret generic mongodb-secret \
    --from-literal=MONGO_INITDB_ROOT_USERNAME="$MONGO_USERNAME" \
    --from-literal=MONGO_INITDB_ROOT_PASSWORD="$MONGO_PASSWORD"

  kubectl -n "$APP_NAMESPACE" create secret generic mongodb-keyfile-secret \
    --from-literal=mongodb-keyfile="$MONGO_KEYFILE"

  unset MONGO_PASSWORD
  unset MONGO_KEYFILE
else
  printf 'Inconsistent MongoDB Secret state in namespace %s: mongodb-secret exists=%s, mongodb-keyfile-secret exists=%s.\n' \
    "$APP_NAMESPACE" "$MONGODB_SECRET_EXISTS" "$MONGODB_KEYFILE_SECRET_EXISTS" >&2
  printf 'Create the missing Secret manually or delete the existing MongoDB Secret pair intentionally before rerunning setup.sh.\n' >&2
  exit 1
fi

kubectl -n "$APP_NAMESPACE" annotate secret mongodb-secret \
  argocd.argoproj.io/sync-options=Prune=false \
  argocd.argoproj.io/compare-options=IgnoreExtraneous \
  --overwrite

kubectl -n "$APP_NAMESPACE" annotate secret mongodb-keyfile-secret \
  argocd.argoproj.io/sync-options=Prune=false \
  argocd.argoproj.io/compare-options=IgnoreExtraneous \
  --overwrite

log "Applying Argo CD Applications"
kubectl apply -f "$ROOT_DIR/argocd/backend-app.yaml"
kubectl apply -f "$ROOT_DIR/argocd/frontend-app.yaml"

log "Waiting for Argo CD Applications to synchronize"
kubectl -n "$ARGOCD_NAMESPACE" wait application/hotel-backend \
  --for=jsonpath='{.status.sync.status}'=Synced \
  --timeout=600s
kubectl -n "$ARGOCD_NAMESPACE" wait application/hotel-frontend \
  --for=jsonpath='{.status.sync.status}'=Synced \
  --timeout=600s
kubectl -n "$ARGOCD_NAMESPACE" wait application/hotel-backend \
  --for=jsonpath='{.status.health.status}'=Healthy \
  --timeout=600s
kubectl -n "$ARGOCD_NAMESPACE" wait application/hotel-frontend \
  --for=jsonpath='{.status.health.status}'=Healthy \
  --timeout=600s

log "Waiting for hotel-project workloads"
kubectl -n "$APP_NAMESPACE" rollout status statefulset/mongodb --timeout=600s
kubectl -n "$APP_NAMESPACE" rollout status deployment/backend-deployment --timeout=600s
kubectl -n "$APP_NAMESPACE" rollout status deployment/frontend-deployment --timeout=600s
kubectl -n "$APP_NAMESPACE" rollout status deployment/mongo-express-deployment --timeout=600s

cat <<'SUMMARY'

Setup complete.

Open:
Frontend:      http://localhost:8080/
Backend API:   http://localhost:8080/api/
Mongo Express: http://localhost:8080/mongo
HTTPS:         https://localhost:8443/

Useful verification commands:
kubectl get pods -n hotel-project
kubectl get applications -n argocd
kubectl get ingress -n hotel-project
SUMMARY
