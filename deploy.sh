#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   deploy.sh <branch-name> <kubeconfig-path> canary <image-tag>
#   deploy.sh <branch-name> <kubeconfig-path> test
#   deploy.sh <branch-name> <kubeconfig-path> canary-live
#   deploy.sh <branch-name> <kubeconfig-path> promote <image-tag>
#   deploy.sh <branch-name> <kubeconfig-path> rollback
#   deploy.sh <branch-name> <kubeconfig-path> delete

BRANCH_NAME="$1"
KUBECONFIG_FILE="$2"
ACTION="$3"
IMAGE_TAG="${4:-}"

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

echo "Environment: $SUFFIX"

KUBECTL=(kubectl --kubeconfig "$KUBECONFIG_FILE")

render() {
  # render <output-dir> <source-files...>
  local outdir="$1"
  shift
  for f in "$@"; do
    sed \
      -e "s/__ENV__/$SUFFIX/g" \
      -e "s/__IMAGE_TAG__/$IMAGE_TAG/g" \
      "k8s/$f" > "$outdir/$f"
  done
}

case "$ACTION" in
  canary)
    if [ -z "$IMAGE_TAG" ]; then
      echo "canary requires an image tag" >&2
      exit 1
    fi

    WORKDIR=$(mktemp -d)
    trap 'rm -rf "$WORKDIR"' EXIT

    render "$WORKDIR" configmap.yaml redis-pvc.yaml redis-deployment.yaml redis-service.yaml backend-canary-deployment.yaml frontend-canary-deployment.yaml

    echo "Deploying canary (env=$SUFFIX, tag=$IMAGE_TAG)"
    "${KUBECTL[@]}" apply -f "$WORKDIR"
    "${KUBECTL[@]}" rollout status "deployment/redis-$SUFFIX" --timeout=120s
    "${KUBECTL[@]}" rollout status "deployment/backend-$SUFFIX-canary" --timeout=120s
    "${KUBECTL[@]}" rollout status "deployment/frontend-$SUFFIX-canary" --timeout=120s
    ;;

  test)
    BACKEND_DEPLOYMENT="backend-$SUFFIX-canary"
    FRONTEND_DEPLOYMENT="frontend-$SUFFIX-canary"

    "${KUBECTL[@]}" port-forward "deployment/$BACKEND_DEPLOYMENT" 9000:9000 &
    BACKEND_PF_PID=$!
    "${KUBECTL[@]}" port-forward "deployment/$FRONTEND_DEPLOYMENT" 8080:8080 &
    FRONTEND_PF_PID=$!

    cleanup() {
      kill "$BACKEND_PF_PID" "$FRONTEND_PF_PID" 2>/dev/null || true
    }
    trap cleanup EXIT

    sleep 3

    chmod +x testing/test.sh
    ./testing/test.sh http://localhost:8080 http://localhost:9000
    ;;

  canary-live)
    echo "Adding canary to live rotation (env=$SUFFIX)"
    PATCH='{"spec":{"template":{"metadata":{"labels":{"expose":"true"}}}}}'
    "${KUBECTL[@]}" patch deployment "backend-$SUFFIX-canary" --type merge -p "$PATCH"
    "${KUBECTL[@]}" patch deployment "frontend-$SUFFIX-canary" --type merge -p "$PATCH"
    "${KUBECTL[@]}" rollout status "deployment/backend-$SUFFIX-canary" --timeout=120s
    "${KUBECTL[@]}" rollout status "deployment/frontend-$SUFFIX-canary" --timeout=120s
    ;;

  promote)
    if [ -z "$IMAGE_TAG" ]; then
      echo "promote requires an image tag" >&2
      exit 1
    fi

    WORKDIR=$(mktemp -d)
    trap 'rm -rf "$WORKDIR"' EXIT

    render "$WORKDIR" configmap.yaml redis-pvc.yaml redis-deployment.yaml redis-service.yaml backend-deployment.yaml frontend-deployment.yaml backend-service.yaml frontend-service.yaml

    echo "Promoting to stable (env=$SUFFIX, tag=$IMAGE_TAG)"
    "${KUBECTL[@]}" apply -f "$WORKDIR"
    "${KUBECTL[@]}" rollout status "deployment/redis-$SUFFIX" --timeout=120s
    "${KUBECTL[@]}" rollout status "deployment/backend-$SUFFIX" --timeout=120s
    "${KUBECTL[@]}" rollout status "deployment/frontend-$SUFFIX" --timeout=120s

    echo "Removing canary"
    "${KUBECTL[@]}" delete deployment "backend-$SUFFIX-canary" "frontend-$SUFFIX-canary" --ignore-not-found
    ;;

  rollback)
    echo "Rolling back: removing canary only, stable is untouched"
    "${KUBECTL[@]}" delete deployment "backend-$SUFFIX-canary" "frontend-$SUFFIX-canary" --ignore-not-found
    ;;

  delete)
    WORKDIR=$(mktemp -d)
    trap 'rm -rf "$WORKDIR"' EXIT

    render "$WORKDIR" configmap.yaml redis-pvc.yaml redis-deployment.yaml redis-service.yaml backend-deployment.yaml frontend-deployment.yaml backend-service.yaml frontend-service.yaml

    echo "Deleting environment: $SUFFIX"
    "${KUBECTL[@]}" delete -f "$WORKDIR" --ignore-not-found
    "${KUBECTL[@]}" delete deployment "backend-$SUFFIX-canary" "frontend-$SUFFIX-canary" --ignore-not-found
    ;;

  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
