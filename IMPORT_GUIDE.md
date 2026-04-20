# AWS Resource Import Guide

This guide helps you import your manually created AWS resources into Terraform state management.

## Prerequisites

1. AWS CLI configured with proper credentials
2. Terraform installed (v1.5.0+)
3. Access to the AWS account with the existing resources

## Step 1: Initialize Terraform

```bash
cd github-action--infra
terraform init
```

This will:
- Download required providers
- Configure S3 backend for state storage
- Set up DynamoDB for state locking

## Step 2: Review Current Resources

Before importing, check what exists in AWS:

```bash
# Check EKS cluster
aws eks describe-cluster --name ecommerce-eks --region ap-south-1

# Check VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ecommerce-eks-vpc" --region ap-south-1

# Check ECR repositories
aws ecr describe-repositories --region ap-south-1

# Check IAM roles
aws iam list-roles --query 'Roles[?contains(RoleName, `ecommerce`) || contains(RoleName, `github-actions`)].RoleName'
```

## Step 3: Run the Import Script

Make the script executable and run it:

```bash
chmod +x import-resources.sh
./import-resources.sh
```

The script will automatically discover and import:
- ✅ VPC and networking (subnets, route tables, NAT gateways, IGW)
- ✅ EKS cluster and node groups
- ✅ IAM roles and policies
- ✅ OIDC provider
- ✅ ECR repositories
- ✅ EKS addons (EBS CSI driver)
- ✅ EKS access entries

## Step 4: Verify the Import

After importing, check if Terraform recognizes the resources:

```bash
terraform plan
```

**Expected output:**
- If import was successful: "No changes. Your infrastructure matches the configuration."
- If there are differences: Review them carefully

## Step 5: Handle Differences

If `terraform plan` shows changes, you have two options:

### Option A: Update Terraform to match AWS (Recommended)

Modify the `.tf` files to match your actual AWS configuration:

```bash
# Example: If node count is different
# Edit variables.tf or eks.tf to match actual values
```

### Option B: Apply Terraform changes to AWS

If Terraform's configuration is correct and AWS needs updating:

```bash
terraform apply
```

⚠️ **Warning:** This will modify your running infrastructure!

## Step 6: Manual Import (If Needed)

If the script misses any resources, import them manually:

```bash
# Example: Import a specific subnet
terraform import 'aws_subnet.public[0]' subnet-xxxxx

# Example: Import IAM role policy attachment
terraform import aws_iam_role_policy_attachment.eks_cluster_policy ecommerce-eks-cluster-role/arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
```

## Common Resources to Import Manually

### IAM Policy Attachments

```bash
# EKS Cluster policies
terraform import aws_iam_role_policy_attachment.eks_cluster_policy \
  ecommerce-eks-cluster-role/arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

# EKS Node policies
terraform import aws_iam_role_policy_attachment.eks_node_policy \
  ecommerce-eks-node-role/arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

terraform import aws_iam_role_policy_attachment.eks_cni_policy \
  ecommerce-eks-node-role/arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

terraform import aws_iam_role_policy_attachment.eks_ecr_policy \
  ecommerce-eks-node-role/arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

### Route Table Associations

```bash
# Get association IDs first
aws ec2 describe-route-tables --region ap-south-1

# Then import
terraform import 'aws_route_table_association.public[0]' rtbassoc-xxxxx
terraform import 'aws_route_table_association.private[0]' rtbassoc-xxxxx
```

## Step 7: Commit to Git

Once everything is imported and `terraform plan` shows no changes:

```bash
git add .
git commit -m "Import existing AWS infrastructure into Terraform"
git push origin main
```

## Troubleshooting

### Error: Resource already exists

This means the resource is already in Terraform state. Safe to ignore.

### Error: Resource not found

The resource doesn't exist in AWS with that name/ID. Check:
1. Resource naming conventions
2. AWS region
3. Resource tags

### Error: Attribute mismatch

Terraform config doesn't match AWS reality. Options:
1. Update `.tf` files to match AWS
2. Use `lifecycle { ignore_changes = [...] }` for dynamic attributes

## Best Practices

1. **Always run `terraform plan` before `apply`**
2. **Review changes carefully** - especially for production
3. **Use version control** - commit after successful imports
4. **Test in dev first** - if you have multiple environments
5. **Document manual changes** - add comments in `.tf` files

## Next Steps

After successful import:

1. ✅ Run `terraform plan` regularly to detect drift
2. ✅ Use GitHub Actions workflow for infrastructure changes
3. ✅ Never make manual AWS changes - always use Terraform
4. ✅ Set up Terraform Cloud/Sentinel for policy enforcement (optional)

## Getting Help

If you encounter issues:

1. Check Terraform state: `terraform state list`
2. Inspect specific resource: `terraform state show aws_eks_cluster.main`
3. Remove from state if needed: `terraform state rm aws_eks_cluster.main`
4. Re-import: `terraform import aws_eks_cluster.main ecommerce-eks`
