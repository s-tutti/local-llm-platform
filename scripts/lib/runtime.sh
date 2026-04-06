#!/usr/bin/env bash
# Shared runtime detection for local K8s cluster management
# Supports: Kind, Minikube
# Usage: source scripts/lib/runtime.sh

CLUSTER_NAME="llm-platform-local"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Auto-detect runtime: prefer Kind if available, fall back to Minikube
detect_runtime() {
  if [[ -n "${K8S_RUNTIME:-}" ]]; then
    echo "$K8S_RUNTIME"
    return
  fi

  if command -v kind &>/dev/null; then
    echo "kind"
  elif command -v minikube &>/dev/null; then
    echo "minikube"
  else
    echo "ERROR: Neither 'kind' nor 'minikube' found. Install one of them." >&2
    exit 1
  fi
}

RUNTIME=$(detect_runtime)

# --- Cluster exists? ---
cluster_exists() {
  case "$RUNTIME" in
    kind)
      kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"
      ;;
    minikube)
      minikube profile list -o json 2>/dev/null | grep -q "\"${CLUSTER_NAME}\""
      ;;
  esac
}

# --- Create cluster ---
cluster_create() {
  case "$RUNTIME" in
    kind)
      cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 8080
        protocol: TCP
      - containerPort: 30090
        hostPort: 9090
        protocol: TCP
      - containerPort: 30030
        hostPort: 3000
        protocol: TCP
EOF
      ;;
    minikube)
      minikube start \
        --profile "$CLUSTER_NAME" \
        --driver=docker \
        --ports=8080:30080,9090:30090,3000:30030 \
        --memory=4096 \
        --cpus=2
      ;;
  esac
}

# --- Delete cluster ---
cluster_delete() {
  case "$RUNTIME" in
    kind)
      kind delete cluster --name "$CLUSTER_NAME"
      ;;
    minikube)
      minikube delete --profile "$CLUSTER_NAME"
      ;;
  esac
}

# --- Set kubectl context ---
cluster_set_context() {
  case "$RUNTIME" in
    kind)
      kubectl cluster-info --context "kind-${CLUSTER_NAME}" >/dev/null 2>&1
      ;;
    minikube)
      kubectl config use-context "$CLUSTER_NAME" >/dev/null 2>&1
      ;;
  esac
}

# --- Load image into cluster ---
cluster_load_image() {
  local image="$1"
  case "$RUNTIME" in
    kind)
      kind load docker-image "$image" --name "$CLUSTER_NAME"
      ;;
    minikube)
      minikube image load "$image" --profile "$CLUSTER_NAME"
      ;;
  esac
}

# --- Check prerequisites ---
check_prerequisites() {
  local required=("docker" "kubectl")

  case "$RUNTIME" in
    kind)     required+=("kind") ;;
    minikube) required+=("minikube") ;;
  esac

  for cmd in "${required[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "ERROR: $cmd is required but not installed."
      exit 1
    fi
  done
}
