output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "ecr_backend_url" {
  description = "ECR URL for backend image"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_url" {
  description = "ECR URL for frontend image"
  value       = aws_ecr_repository.frontend.repository_url
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint (use this as DB_HOST in K8s secret)"
  value       = aws_db_instance.mysql.endpoint
  sensitive   = true
}
