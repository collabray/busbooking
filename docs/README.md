# OmniBus EA - Production Platform

## Overview
OmniBus EA is a production-grade intercity bus booking aggregator and logistics marketplace serving Kenya, Uganda, and Tanzania.

## Architecture
- **Multi-Region Active-Active**: af-south-1 (Cape Town) + me-south-1 (Bahrain)
- **Microservices**: 9 polyglot services (Go, Rust, Java, Python, Node.js/TypeScript)
- **Database**: Amazon Aurora PostgreSQL Serverless v2 with read replicas
- **Cache**: ElastiCache Redis Cluster (16 shards)
- **Messaging**: MSK Kafka + RabbitMQ
- **Search**: OpenSearch for route discovery
- **Mesh**: Istio with mTLS

## Services

| Service | Language | Port | Description |
|---------|----------|------|-------------|
| auth-service | Go | 8081/9091 | OAuth2/OIDC, JWT, WebAuthn, KMS encryption |
| booking-service | Go | 8082/9092 | Redlock seat allocation, PNR generation |
| inventory-service | Rust | 8083 | Route topology, schedules, seat layouts |
| payment-service | Java Spring Boot | 8084 | M-Pesa, Airtel, Tigo, MTN, DPO |
| ticket-service | Rust | 8085 | Ed25519 signing, SecQR generation |
| notification-service | Python/FastAPI | 8086 | FCM, SMS, WhatsApp |
| wallet-service | Go | 8087 | Double-entry ledger, payouts |
| cargo-service | Node.js/TypeScript | 8088 | Parcel booking, tracking |
| admin-service | NestJS/TypeScript | 8089 | Fleet, pricing, audit management |

## Quick Start

### Prerequisites
- Docker & Docker Compose
- kubectl
- Terraform >= 1.7
- AWS CLI configured

### Local Development
```bash
cd infra/docker
cp .env.example .env
# Edit .env with your credentials
docker-compose up -d
```

### Production Deployment
```bash
cd infra/terraform
terraform init
terraform plan -var="db_password=YOUR_SECURE_PASSWORD"
terraform apply
```

## Admin Operations

### Register a Bus Company (Operator)
```bash
curl -X POST https://api.omnibus.ea/api/v1/admin/fleet/operators   -H "Authorization: Bearer $ADMIN_TOKEN"   -H "Content-Type: application/json"   -d '{
    "company_name": "Modern Coast Express",
    "country_code": "KEN",
    "contact_email": "ops@moderncoast.co.ke",
    "contact_phone": "+254722000000",
    "commission_rate": 8.0,
    "settlement_account": {
      "bank_name": "KCB",
      "account_number": "1234567890",
      "swift_code": "KCBLKENX"
    }
  }'
```

### Add a Bus to Fleet
```bash
curl -X POST https://api.omnibus.ea/api/v1/admin/fleet/buses   -H "Authorization: Bearer $ADMIN_TOKEN"   -H "Content-Type: application/json"   -d '{
    "operator_id": "UUID_FROM_ABOVE",
    "registration_number": "KBC 123X",
    "capacity": 45,
    "bus_type": "VIP",
    "amenities": {"wifi":true,"ac":true,"charger":true}
  }'
```

### Create Fare Rule
```bash
curl -X POST https://api.omnibus.ea/api/v1/admin/fleet/fare-rules   -H "Authorization: Bearer $ADMIN_TOKEN"   -H "Content-Type: application/json"   -d '{
    "route_id": "ROUTE_UUID",
    "bus_type": "VIP",
    "base_price_kes": 3500,
    "base_price_ugx": 85000,
    "base_price_tzs": 45000,
    "base_price_usd": 25.00
  }'
```

### Configure External API for Fare Fetching
```bash
curl -X POST https://api.omnibus.ea/api/v1/admin/fleet/operators/UUID/api-config   -H "Authorization: Bearer $ADMIN_TOKEN"   -H "Content-Type: application/json"   -d '{
    "api_name": "Modern Coast API",
    "api_base_url": "https://api.moderncoast.co.ke/v2",
    "api_version": "v2",
    "auth_type": "API_KEY",
    "auth_config": {
      "header_name": "X-API-Key",
      "key_value": "your-api-key"
    },
    "endpoints": {
      "get_routes": "/routes",
      "get_fares": "/fares",
      "get_schedules": "/schedules"
    },
    "sync_enabled": true,
    "sync_interval_minutes": 60
  }'
```

### Trigger Manual Fare Sync
```bash
curl -X POST https://api.omnibus.ea/api/v1/admin/fleet/operators/UUID/sync-fares   -H "Authorization: Bearer $ADMIN_TOKEN"
```

## Security
- All PII encrypted with AES-256-GCM via AWS KMS
- mTLS between all services via Istio
- Rate limiting: 100 req/sec per IP
- WebAuthn/FIDO2 for admin authentication
- 4-eyes principle for sensitive operations

## License
Proprietary - OmniBus EA Ltd
