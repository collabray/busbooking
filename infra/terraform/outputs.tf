output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "rds_cluster_endpoint" {
  description = "RDS cluster writer endpoint"
  value       = aws_rds_cluster.omnibus.endpoint
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.omnibus.primary_endpoint_address
}

output "msk_bootstrap_brokers" {
  description = "MSK bootstrap brokers"
  value       = aws_msk_cluster.omnibus.bootstrap_brokers_tls
}

output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint"
  value       = aws_opensearch_domain.omnibus.endpoint
}
