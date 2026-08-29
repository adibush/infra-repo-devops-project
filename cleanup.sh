#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-hotel-local}"

cat <<EOF
This will delete the local kind cluster named "${CLUSTER_NAME}".
All Kubernetes resources and local persistent data inside that cluster will be removed.
EOF

read -r -p "Type 'delete' to continue: " CONFIRMATION

if [ "$CONFIRMATION" != "delete" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

kind delete cluster --name "$CLUSTER_NAME"
