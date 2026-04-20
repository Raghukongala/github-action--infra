output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "ecr_urls" {
  value = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
