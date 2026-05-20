# ─── Security Group for RDS ─────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.app_name}-rds-sg"
  description = "Allow MySQL from EKS nodes only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.eks.cluster_security_group_id]
  }

  tags = var.common_tags
}

# ─── RDS Subnet Group ───────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.app_name}-db-subnet"
  subnet_ids = module.vpc.private_subnets
  tags       = var.common_tags
}

# ─── RDS MySQL Instance ─────────────────────────────────────────────
resource "aws_db_instance" "mysql" {
  identifier = "${var.app_name}-mysql"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"   # upgrade to db.t3.small+ for production

  db_name  = "medical"
  username = "admin"
  password = var.db_password   # stored in terraform.tfvars (gitignored)

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az               = false  # set true for HA
  publicly_accessible    = false
  skip_final_snapshot    = false
  final_snapshot_identifier = "${var.app_name}-final-snapshot"

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  tags = var.common_tags
}
