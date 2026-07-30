# Deployment Guide

## AWS Infrastructure

### 1. Bootstrap Terraform Backend
```bash
aws s3api create-bucket   --bucket omnibus-terraform-state   --region af-south-1   --create-bucket-configuration LocationConstraint=af-south-1

aws dynamodb create-table   --table-name omnibus-terraform-locks   --attribute-definitions AttributeName=LockID,AttributeType=S   --key-schema AttributeName=LockID,KeyType=HASH   --billing-mode PAY_PER_REQUEST   --region af-south-1
```

### 2. Deploy Infrastructure
```bash
cd infra/terraform
terraform init
terraform plan
terraform apply
```

### 3. Configure kubectl
```bash
aws eks update-kubeconfig --region af-south-1 --name omnibus-eks
```

### 4. Deploy Services
```bash
kubectl apply -f infra/k8s/namespace.yaml
kubectl apply -f infra/k8s/configmap.yaml
kubectl apply -f infra/k8s/service-account.yaml
kubectl apply -f infra/k8s/istio-gateway.yaml
kubectl apply -f infra/k8s/auth-service.yaml
kubectl apply -f infra/k8s/booking-service.yaml
# ... apply remaining services
```

### 5. Database Migrations
```bash
# Connect to Aurora
psql -h $(terraform output -raw rds_cluster_endpoint) -U omnibus_admin -d omnibus

# Run migrations
psql -h $(terraform output -raw rds_cluster_endpoint) -U omnibus_admin -d omnibus -f database/migrations/001_init.sql
```

## Monitoring
- Prometheus metrics exposed on /metrics
- Grafana dashboards for service health
- CloudWatch for AWS resource monitoring
- OpenSearch for log aggregation
