#!/bin/bash
# Script to import existing AWS resources into Terraform state

set -e

CLUSTER_NAME="ecommerce-eks"
AWS_REGION="ap-south-1"

echo "🔍 Discovering existing AWS resources..."

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=${CLUSTER_NAME}-vpc" \
  --query 'Vpcs[0].VpcId' \
  --output text \
  --region $AWS_REGION)

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  echo "✅ Found VPC: $VPC_ID"
  terraform import aws_vpc.main $VPC_ID || echo "⚠️  VPC already imported or doesn't exist"
else
  echo "❌ VPC not found - will be created"
fi

# Get Internet Gateway
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text \
    --region $AWS_REGION)
  
  if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
    echo "✅ Found Internet Gateway: $IGW_ID"
    terraform import aws_internet_gateway.main $IGW_ID || echo "⚠️  IGW already imported"
  fi
fi

# Get Subnets
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  echo "🔍 Importing subnets..."
  
  # Public subnets
  PUBLIC_SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${CLUSTER_NAME}-public-*" \
    --query 'Subnets[*].SubnetId' \
    --output text \
    --region $AWS_REGION)
  
  i=0
  for subnet in $PUBLIC_SUBNETS; do
    echo "✅ Importing public subnet $i: $subnet"
    terraform import "aws_subnet.public[$i]" $subnet || echo "⚠️  Already imported"
    ((i++))
  done
  
  # Private subnets
  PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${CLUSTER_NAME}-private-*" \
    --query 'Subnets[*].SubnetId' \
    --output text \
    --region $AWS_REGION)
  
  i=0
  for subnet in $PRIVATE_SUBNETS; do
    echo "✅ Importing private subnet $i: $subnet"
    terraform import "aws_subnet.private[$i]" $subnet || echo "⚠️  Already imported"
    ((i++))
  done
fi

# Get NAT Gateways
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  NAT_GWS=$(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
    --query 'NatGateways[*].NatGatewayId' \
    --output text \
    --region $AWS_REGION)
  
  i=0
  for nat in $NAT_GWS; do
    echo "✅ Importing NAT Gateway $i: $nat"
    terraform import "aws_nat_gateway.main[$i]" $nat || echo "⚠️  Already imported"
    
    # Get EIP for NAT
    EIP_ID=$(aws ec2 describe-nat-gateways \
      --nat-gateway-ids $nat \
      --query 'NatGateways[0].NatGatewayAddresses[0].AllocationId' \
      --output text \
      --region $AWS_REGION)
    
    if [ "$EIP_ID" != "None" ] && [ -n "$EIP_ID" ]; then
      echo "✅ Importing EIP $i: $EIP_ID"
      terraform import "aws_eip.nat[$i]" $EIP_ID || echo "⚠️  Already imported"
    fi
    ((i++))
  done
fi

# Get Route Tables
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  # Public route table
  PUBLIC_RT=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${CLUSTER_NAME}-public-rt" \
    --query 'RouteTables[0].RouteTableId' \
    --output text \
    --region $AWS_REGION)
  
  if [ "$PUBLIC_RT" != "None" ] && [ -n "$PUBLIC_RT" ]; then
    echo "✅ Importing public route table: $PUBLIC_RT"
    terraform import aws_route_table.public $PUBLIC_RT || echo "⚠️  Already imported"
  fi
  
  # Private route tables
  PRIVATE_RTS=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${CLUSTER_NAME}-private-rt-*" \
    --query 'RouteTables[*].RouteTableId' \
    --output text \
    --region $AWS_REGION)
  
  i=0
  for rt in $PRIVATE_RTS; do
    echo "✅ Importing private route table $i: $rt"
    terraform import "aws_route_table.private[$i]" $rt || echo "⚠️  Already imported"
    ((i++))
  done
fi

# Import EKS Cluster
echo "🔍 Importing EKS cluster..."
terraform import aws_eks_cluster.main $CLUSTER_NAME || echo "⚠️  Cluster already imported or doesn't exist"

# Import EKS Node Group
NODE_GROUP=$(aws eks list-nodegroups \
  --cluster-name $CLUSTER_NAME \
  --query 'nodegroups[0]' \
  --output text \
  --region $AWS_REGION 2>/dev/null || echo "")

if [ -n "$NODE_GROUP" ] && [ "$NODE_GROUP" != "None" ]; then
  echo "✅ Importing node group: $NODE_GROUP"
  terraform import aws_eks_node_group.main "${CLUSTER_NAME}:${NODE_GROUP}" || echo "⚠️  Already imported"
fi

# Import IAM Roles
echo "🔍 Importing IAM roles..."

# EKS Cluster Role
CLUSTER_ROLE=$(aws iam get-role --role-name "${CLUSTER_NAME}-cluster-role" --query 'Role.RoleName' --output text 2>/dev/null || echo "")
if [ -n "$CLUSTER_ROLE" ] && [ "$CLUSTER_ROLE" != "None" ]; then
  terraform import aws_iam_role.eks_cluster $CLUSTER_ROLE || echo "⚠️  Already imported"
fi

# EKS Node Role
NODE_ROLE=$(aws iam get-role --role-name "${CLUSTER_NAME}-node-role" --query 'Role.RoleName' --output text 2>/dev/null || echo "")
if [ -n "$NODE_ROLE" ] && [ "$NODE_ROLE" != "None" ]; then
  terraform import aws_iam_role.eks_node $NODE_ROLE || echo "⚠️  Already imported"
fi

# GitHub Actions Role
GH_ROLE=$(aws iam get-role --role-name "github-actions-eks-role" --query 'Role.RoleName' --output text 2>/dev/null || echo "")
if [ -n "$GH_ROLE" ] && [ "$GH_ROLE" != "None" ]; then
  terraform import aws_iam_role.github_actions $GH_ROLE || echo "⚠️  Already imported"
fi

# ALB Controller Role
ALB_ROLE=$(aws iam get-role --role-name "AmazonEKSLoadBalancerControllerRole" --query 'Role.RoleName' --output text 2>/dev/null || echo "")
if [ -n "$ALB_ROLE" ] && [ "$ALB_ROLE" != "None" ]; then
  terraform import aws_iam_role.alb_controller $ALB_ROLE || echo "⚠️  Already imported"
fi

# Import OIDC Provider
OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.identity.oidc.issuer' --output text --region $AWS_REGION 2>/dev/null | sed 's|https://||')
if [ -n "$OIDC_URL" ]; then
  OIDC_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, '$OIDC_URL')].Arn" --output text)
  if [ -n "$OIDC_ARN" ]; then
    echo "✅ Importing OIDC provider: $OIDC_ARN"
    terraform import aws_iam_openid_connect_provider.eks $OIDC_ARN || echo "⚠️  Already imported"
  fi
fi

# Import ECR Repositories
echo "🔍 Importing ECR repositories..."
ECR_REPOS=("frontend" "user-service" "product-service" "order-service" "payment-service")

for repo in "${ECR_REPOS[@]}"; do
  REPO_NAME="ecommerce/${repo}"
  if aws ecr describe-repositories --repository-names $REPO_NAME --region $AWS_REGION &>/dev/null; then
    echo "✅ Importing ECR repo: $REPO_NAME"
    terraform import "aws_ecr_repository.repos[\"$repo\"]" $REPO_NAME || echo "⚠️  Already imported"
  fi
done

# Import EKS Addons
echo "🔍 Importing EKS addons..."
terraform import aws_eks_addon.ebs_csi "${CLUSTER_NAME}:aws-ebs-csi-driver" || echo "⚠️  Addon not found or already imported"

# Import EKS Access Entry
echo "🔍 Importing EKS access entries..."
if [ -n "$GH_ROLE" ]; then
  GH_ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$GH_ROLE"
  terraform import aws_eks_access_entry.github_actions "${CLUSTER_NAME}#${GH_ROLE_ARN}" || echo "⚠️  Already imported"
fi

echo ""
echo "✅ Import complete! Run 'terraform plan' to see if there are any differences."
echo "⚠️  Review the plan carefully before applying changes."
