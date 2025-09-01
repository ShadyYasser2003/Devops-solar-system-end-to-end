#!/bin/bash

# اسم الـ Cluster بتاعك
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region 2>/dev/null || echo "us-east-1")

echo "📡 Getting worker nodes for cluster: $CLUSTER_NAME in $REGION ..."
echo "--------------------------------------"

# هات أسماء الـ nodes
NODES=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

for NODE in $NODES; do
    # هات الـ instance ID من الـ providerID
    INSTANCE_ID=$(kubectl get node $NODE -o jsonpath='{.spec.providerID}' | cut -d'/' -f5)

    # هات الـ Public IP من AWS CLI
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --region $REGION \
        --query "Reservations[*].Instances[*].PublicIpAddress" \
        --output text)

    echo "Node: $NODE | InstanceID: $INSTANCE_ID | PublicIP: $PUBLIC_IP"
done
