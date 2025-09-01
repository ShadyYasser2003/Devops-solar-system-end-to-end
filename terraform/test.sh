#!/bin/bash

set -e

# -------------------------------
# إعداد متغيرات أساسية
# -------------------------------
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region 2>/dev/null || echo "us-east-1")
VPC_ID=$(terraform output -raw vpc_id)
ALB_ROLE_ARN=$(terraform output -raw alb_controller_role_arn)

echo "🔧 Setting up EKS cluster: $CLUSTER_NAME"
echo "📍 Region: $REGION"
echo "🌐 VPC ID: $VPC_ID"

# -------------------------------
# تحديث kubeconfig
# -------------------------------
echo "🔄 Updating kubeconfig..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# -------------------------------
# التحقق من حالة الكلاستر
# -------------------------------
kubectl get nodes

# -------------------------------
# إنشاء/تحديث Service Account للـ AWS Load Balancer Controller
# -------------------------------
echo "🔧 Checking ServiceAccount for AWS Load Balancer Controller..."
if kubectl get sa aws-load-balancer-controller -n kube-system >/dev/null 2>&1; then
  echo "ℹ️ ServiceAccount already exists. Patching/Updating..."
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: $ALB_ROLE_ARN
EOF
else
  echo "✅ Creating ServiceAccount..."
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: $ALB_ROLE_ARN
EOF
fi

# -------------------------------
# تثبيت/تحديث AWS Load Balancer Controller
# -------------------------------
helm repo add eks https://aws.github.io/eks-charts || true
helm repo update

echo "🚀 Installing/Upgrading AWS Load Balancer Controller..."
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$REGION \
  --set vpcId=$VPC_ID

# -------------------------------
# تثبيت/تحديث NGINX Ingress Controller
# -------------------------------
echo "🚀 Installing/Upgrading NGINX Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=2 \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=alb \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing

# -------------------------------
# انتظار حتى يصبح Ingress Controller جاهز
# -------------------------------
echo "⏳ Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=300s

# -------------------------------
# الحصول على Load Balancer URL
# -------------------------------
echo "🌐 Getting Load Balancer URL..."
LB_URL=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Not ready yet")

if [ "$LB_URL" != "Not ready yet" ] && [ ! -z "$LB_URL" ]; then
    echo "✅ Ingress Controller is accessible at: http://$LB_URL"
    echo "📝 Note: It may take a few minutes for the DNS to propagate"
else
    echo "⏳ Load Balancer is still being created. Check again in a few minutes with:"
    echo "   kubectl get svc -n ingress-nginx"
fi
