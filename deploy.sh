#!/usr/bin/env bash
set -euo pipefail

# Usage: deploy.sh <branch-name> <kubeconfig-path> [--delete]
BRANCH_NAME="$1"
KUBECONFIG_FILE="$2"
ACTION="${3:-apply}"

# Turn a branch name like "feature/add-cache" into a safe suffix like "feature-add-cache"
SUFFIX=$(echo "$BRANCH_NAME" \
  | tr '[:upper:]' '[:lower:]' \
  | tr '/_.' '-' \
  | tr -cd 'a-z0-9-' \
  | cut -c1-20)

if [ -z "$SUFFIX" ]; then
  echo "Could not derive a valid suffix from branch name '$BRANCH_NAME'" >&2
  exit 1
fi

echo "Deployment suffix: $SUFFIX"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

cp k8s/*.yaml "$WORKDIR"/

for f in "$WORKDIR"/*.yaml; do
  sed -i \
    -e "s/backend-v1/backend-$SUFFIX/g" \
    -e "s/frontend-v1/frontend-$SUFFIX/g" \
    -e "s/version: v1/version: $SUFFIX/g" \
    "$f"
done

if [ "$ACTION" = "--delete" ]; then
  echo "Deleting deployment with suffix: $SUFFIX"

  kubectl \
    --kubeconfig "$KUBECONFIG_FILE" \
    delete \
    -f "$WORKDIR" \
    --ignore-not-found

  exit 0
fi

echo "Deploying with suffix: $SUFFIX"

kubectl \
  --kubeconfig "$KUBECONFIG_FILE" \
  apply \
  -f "$WORKDIR"