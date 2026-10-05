#!/bin/bash
set -e

echo "=========================================================="
echo " 🚀 HydraDB Minikube Automated Setup & Deployment"
echo "=========================================================="

# 1. Check tools
command -v minikube >/dev/null 2>&1 || { echo "❌ Minikube is not installed. Please install Minikube first."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ Kubectl is not installed. Please install kubectl first."; exit 1; }

# 2. Check if Minikube is running
echo "🔍 Checking Minikube status..."
if ! minikube status >/dev/null 2>&1; then
    echo "⚡ Starting Minikube with recommended resources (4 CPUs, 4GB RAM)..."
    minikube start --cpus=4 --memory=4096
else
    echo "✅ Minikube is already running."
fi

# 3. Enable essential addons
echo "🔧 Enabling Minikube addons: ingress, metrics-server..."
minikube addons enable ingress
minikube addons enable metrics-server

# 4. Build Images directly in Minikube Docker environment
echo "📦 Building container images inside Minikube..."
eval $(minikube docker-env)

echo "--> Building PostgreSQL + Patroni image..."
docker build -t hydradb-postgres:latest -f docker/postgres/Dockerfile.patroni docker/postgres

echo "--> Building NestJS App image..."
docker build -t hydradb-nestapp:latest -f nestapp/Dockerfile nestapp

echo "--> Building Go Gin App image..."
docker build -t hydradb-goapp:latest -f goapp/Dockerfile goapp

# 5. Wait for Ingress controller readiness before applying ingress resource
echo "⏳ Waiting for Ingress controller readiness..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s 2>/dev/null || true

# 6. Apply Kubernetes manifests
echo "☸️ Applying Kubernetes manifests from k8s/..."
kubectl apply -f k8s/

# 6. Wait for core services
echo "⏳ Waiting for etcd to be ready..."
kubectl rollout status statefulset/etcd --timeout=120s || true

echo "⏳ Waiting for PostgreSQL Primary to be ready..."
kubectl rollout status statefulset/pg-primary --timeout=120s || true

echo "⏳ Waiting for PostgreSQL Replica to be ready..."
kubectl rollout status statefulset/pg-replica --timeout=120s || true

echo "⏳ Waiting for HAProxy and PgBouncers..."
kubectl rollout status deployment/haproxy --timeout=120s || true
kubectl rollout status deployment/pgbouncer-primary --timeout=120s || true
kubectl rollout status deployment/pgbouncer-replica --timeout=120s || true

echo "⏳ Waiting for App deployments..."
kubectl rollout status deployment/nestapp --timeout=120s || true
kubectl rollout status deployment/goapp --timeout=120s || true

echo ""
echo "=========================================================="
echo " 🎉 HydraDB Cluster Deployed Successfully!"
echo "=========================================================="
kubectl get pods -o wide
echo ""
kubectl get svc
echo ""
kubectl get ingress
echo ""

OS_TYPE="$(uname -s)"
if [ "$OS_TYPE" = "Darwin" ]; then
    echo "⚠️ NOTE FOR macOS USERS:"
    echo "On macOS (Docker driver), direct Ingress routing via \$(minikube ip) requires 'minikube tunnel'."
    echo "Please open a new terminal window and run:"
    echo "    minikube tunnel"
    echo ""
    echo "Alternatively, you can test via port-forwarding:"
    echo "    kubectl port-forward svc/nestapp 3000:3000 &"
    echo "    kubectl port-forward svc/goapp 8080:8080 &"
fi
