terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "omnibus-terraform-state"
    key            = "omnibus-ea/terraform.tfstate"
    region         = "af-south-1"
    encrypt        = true
    dynamodb_table = "omnibus-terraform-locks"
  }
}

provider "aws" {
  region = var.primary_region
  default_tags {
    tags = {
      Project     = "OmniBus-EA"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "omnibus-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.primary_region}a", "${var.primary_region}b", "${var.primary_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true

  tags = { Name = "omnibus-vpc" }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "omnibus-eks"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    general = {
      desired_size = 3
      min_size     = 3
      max_size     = 20

      instance_types = ["m6i.2xlarge"]
      capacity_type  = "ON_DEMAND"

      labels = { workload = "general" }

      taints = []

      update_config = {
        max_unavailable_percentage = 25
      }
    }

    spot = {
      desired_size = 2
      min_size     = 2
      max_size     = 50

      instance_types = ["m6i.xlarge", "m5.xlarge", "m5a.xlarge"]
      capacity_type  = "SPOT"

      labels = { workload = "spot" }
    }
  }

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
  }

  enable_irsa = true
}

# Aurora PostgreSQL Serverless v2
resource "aws_rds_cluster" "omnibus" {
  cluster_identifier        = "omnibus-aurora"
  engine                    = "aurora-postgresql"
  engine_version            = "15.4"
  engine_mode               = "provisioned"
  database_name             = "omnibus"
  master_username           = var.db_username
  master_password           = var.db_password

  serverlessv2_scaling_configuration {
    min_capacity = 2
    max_capacity = 64
  }

  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.omnibus.name

  backup_retention_period = 35
  preferred_backup_window = "03:00-04:00"

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "omnibus-final-snapshot"

  enabled_cloudwatch_logs_exports = ["postgresql"]
}

resource "aws_rds_cluster_instance" "omnibus" {
  count              = 2
  identifier         = "omnibus-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.omnibus.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.omnibus.engine
}

resource "aws_db_subnet_group" "omnibus" {
  name       = "omnibus-db-subnet-group"
  subnet_ids = module.vpc.database_subnets
  tags       = { Name = "omnibus-db-subnet-group" }
}

# ElastiCache Redis Cluster
resource "aws_elasticache_replication_group" "omnibus" {
  replication_group_id = "omnibus-redis"
  description          = "OmniBus Redis cluster"

  node_type            = "cache.r6g.xlarge"
  num_cache_clusters   = 3
  automatic_failover_enabled = true
  multi_az_enabled     = true

  engine               = "redis"
  engine_version       = "7.1"
  port                 = 6379

  parameter_group_name = aws_elasticache_parameter_group.omnibus.name
  subnet_group_name    = aws_elasticache_subnet_group.omnibus.name
  security_group_ids   = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  snapshot_retention_limit = 7
  snapshot_window          = "05:00-06:00"
}

resource "aws_elasticache_parameter_group" "omnibus" {
  family = "redis7"
  name   = "omnibus-redis-params"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
}

resource "aws_elasticache_subnet_group" "omnibus" {
  name       = "omnibus-redis-subnet-group"
  subnet_ids = module.vpc.database_subnets
}

# MSK Kafka
resource "aws_msk_cluster" "omnibus" {
  cluster_name           = "omnibus-kafka"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type   = "kafka.m5.large"
    client_subnets  = module.vpc.private_subnets
    security_groups = [aws_security_group.kafka.id]

    storage_info {
      ebs_storage_info {
        volume_size = 1000
      }
    }
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.msk.arn
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
    }
  }
}

# OpenSearch
resource "aws_opensearch_domain" "omnibus" {
  domain_name    = "omnibus-search"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type          = "r6g.large.search"
    instance_count         = 3
    zone_awareness_enabled = true
    zone_awareness_config {
      availability_zone_count = 3
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = 100
  }

  encrypt_at_rest {
    enabled = true
    kms_key_id = aws_kms_key.opensearch.arn
  }

  node_to_node_encryption { enabled = true }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  vpc_options {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.opensearch.id]
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { AWS = "*" }
      Action = "es:*"
      Resource = "arn:aws:es:${var.primary_region}:${data.aws_caller_identity.current.account_id}:domain/omnibus-search/*"
    }]
  })
}

# DynamoDB Tables
resource "aws_dynamodb_table" "payment_idempotency" {
  name         = "OmniBus_Payment_Idempotency"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "paymentRef"

  attribute {
    name = "paymentRef"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    projection_type = "ALL"
  }

  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_dynamodb_table" "admin_audit_ledger" {
  name         = "OmniBus_Admin_Audit_Ledger"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ADMIN_ID"
  range_key    = "TIMESTAMP_ACTION_ID"

  attribute {
    name = "ADMIN_ID"
    type = "S"
  }

  attribute {
    name = "TIMESTAMP_ACTION_ID"
    type = "S"
  }

  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

# KMS Keys
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = true
}

resource "aws_kms_key" "msk" {
  description             = "KMS key for MSK encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_key" "opensearch" {
  description             = "KMS key for OpenSearch encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

# Security Groups
resource "aws_security_group" "database" {
  name_prefix = "omnibus-db-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "redis" {
  name_prefix = "omnibus-redis-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

resource "aws_security_group" "kafka" {
  name_prefix = "omnibus-kafka-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  ingress {
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

resource "aws_security_group" "opensearch" {
  name_prefix = "omnibus-os-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

# Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "omnibus/db-password"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/omnibus-kafka"
  retention_in_days = 30
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
