#!/bin/bash

set -e

# -------------------------------
# إعداد متغيرات أساسية
# -------------------------------
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region 2>/dev/null || echo "us-east-1")
VPC_ID=$(terraform output -raw vpc_id)
# EBS_ROLE_ARN=$(terraform output -raw ebs_csi_role_arn)
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
echo "🔍 Checking cluster status..."
kubectl get nodes

# -------------------------------
# إنشاء Service Account للـ AWS Load Balancer Controller
# -------------------------------
echo "🔧 Creating service account for AWS Load Balancer Controller..."
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

# -------------------------------
# تثبيت AWS Load Balancer Controller
# -------------------------------
echo "🚀 Installing AWS Load Balancer Controller..."

# إضافة Helm repository
helm repo add eks https://aws.github.io/eks-charts || true
helm repo update

# تثبيت AWS Load Balancer Controller
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$REGION \
  --set vpcId=$VPC_ID

# -------------------------------
# تثبيت AWS EBS CSI Driver
# -------------------------------
# echo "🚀 Installing AWS EBS CSI Driver..."

# # إضافة Helm repository للـ EBS CSI Driver
# helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver || true
# helm repo update

# # تثبيت EBS CSI Driver
# helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
#   --namespace kube-system \
#   --set controller.serviceAccount.create=true \
#   --set controller.serviceAccount.name=ebs-csi-controller-sa \
#   --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$EBS_ROLE_ARN

# -------------------------------
# انتظار حتى يصبح Load Balancer Controller جاهز
# -------------------------------
echo "⏳ Waiting for AWS Load Balancer Controller to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s

# -------------------------------
# انتظار حتى يصبح EBS CSI Driver جاهز
# -------------------------------
# echo "⏳ Waiting for EBS CSI Driver to be ready..."
# kubectl wait --for=condition=ready pod -l app=ebs-csi-controller -n kube-system --timeout=300s

# -------------------------------
# نشر التطبيق
# -------------------------------
# echo "🚀 Deploying the voting application..."
# kubectl apply -f all-file-copy.yaml

# -------------------------------
# انتظار حتى تصبح جميع الـ pods جاهزة
# -------------------------------
# echo "⏳ Waiting for all pods to be ready..."
# kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s
# kubectl wait --for=condition=ready pod -l app=backend --timeout=300s
# kubectl wait --for=condition=ready pod -l app=frontend --timeout=300s

# # -------------------------------
# # عرض حالة التطبيق
# # -------------------------------
# echo "📊 Application Status:"
# kubectl get pods
# echo ""
# kubectl get services
# echo ""
# kubectl get ingress

# -------------------------------
# الحصول على Load Balancer URL
# -------------------------------
echo "🌐 Getting Load Balancer URL..."
ALB_URL=$(kubectl get ingress voting-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Not ready yet")

if [ "$ALB_URL" != "Not ready yet" ] && [ ! -z "$ALB_URL" ]; then
    echo "✅ Application is accessible at: http://$ALB_URL"
    echo "📝 Note: It may take a few minutes for the DNS to propagate"
else
    echo "⏳ Load Balancer is still being created. Check again in a few minutes with:"
    echo "   kubectl get ingress"
fi

# # -------------------------------
# # إنهاء
# # -------------------------------
# echo "✅ Setup completed successfully!"
# echo ""
# echo "🔧 Useful commands:"
# echo "   kubectl get pods                    # Check pod status"
# echo "   kubectl get services                # Check services"
# echo "   kubectl get ingress                 # Check ingress and ALB"
# echo "   kubectl logs -l app=backend         # Check backend logs"
# echo "   kubectl logs -l app=frontend        # Check frontend logs"
# echo "   kubectl logs -l app=postgres        # Check database logs"