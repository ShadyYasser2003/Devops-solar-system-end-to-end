#!/bin/bash

set -e

# -------------------------------
# إعداد متغيرات أساسية
# -------------------------------
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region 2>/dev/null || echo "us-east-1")

echo "🔧 Setting up EKS cluster: $CLUSTER_NAME"
echo "📍 Region: $REGION"

# -------------------------------
# تحديث kubeconfig
# -------------------------------
echo "🔄 Updating kubeconfig..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# -------------------------------
# تثبيت Nginx Ingress Controller كـ NodePort
# -------------------------------
echo "🚀 Installing Nginx Ingress Controller (NodePort)..."

# إضافة Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm repo update

# تثبيت Ingress Nginx مع تغيير الـ service لنوع NodePort
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=32080 \
  --set controller.service.nodePorts.https=32443

# -------------------------------
# انتظار لحد ما يجهز
# -------------------------------
echo "⏳ Waiting for ingress-nginx controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  -l app.kubernetes.io/component=controller \
  --timeout=300s

# -------------------------------
# عرض البيانات
# -------------------------------
echo "📊 Ingress Controller Service:"
kubectl get svc -n ingress-nginx ingress-nginx-controller

echo "🌐 Access your Ingress via NodePort:"
NODES=$(kubectl get nodes -o wide | awk 'NR>1 {print $6}')
echo "Available worker node IPs:"
echo "$NODES"
echo ""
echo "➡️  Use http://<NODE_IP>:32080 for HTTP"
echo "➡️  Use https://<NODE_IP>:32443 for HTTPS"
