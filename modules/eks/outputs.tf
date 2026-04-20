output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  value = aws_security_group.eks_cluster.id
}

output "node_security_group_id" {
  value = aws_security_group.eks_nodes.id
}

output "node_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL – Pod Identity-hez kell"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}