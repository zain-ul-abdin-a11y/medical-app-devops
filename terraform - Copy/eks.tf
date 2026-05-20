# ─── EKS Cluster ────────────────────────────────────────────────────
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.0.0"

  cluster_name    = "${var.app_name}-cluster"
  cluster_version = "1.28"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # Node groups
  eks_managed_node_groups = {
    main = {
      name           = "${var.app_name}-nodes"
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 5
      desired_size   = 2

      labels = {
        Environment = var.environment
      }
    }
  }

  tags = var.common_tags
}
