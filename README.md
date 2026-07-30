# OmniBus EA - East Africa Intercity Bus Platform

## Production-Grade Intercity Bus Booking Aggregator

OmniBus EA is a fintech-grade intercity bus booking and logistics marketplace serving Kenya (KE), Uganda (UG), and Tanzania (TZ).

## Platform Components

### Mobile Apps
- **Passenger App** (`mobile/passenger_app/`): Flutter app for Android (API 24+)
- **Conductor App** (`mobile/conductor_app/`): Flutter app with offline QR scanning

### Web Portals
- **Passenger Portal** (`web/passenger-portal/`): Next.js 14+ PWA
- **Admin Portal** (`web/admin-portal/`): Next.js 14+ Super-Admin dashboard

### Backend Microservices
- **Auth Service** (`services/auth-service/`): Go - OAuth2/OIDC, JWT, WebAuthn
- **Booking Service** (`services/booking-service/`): Go - Redlock seat allocation
- **Inventory Service** (`services/inventory-service/`): Rust - Routes, schedules
- **Payment Service** (`services/payment-service/`): Java Spring Boot - M-Pesa, Airtel, Tigo
- **Ticket Service** (`services/ticket-service/`): Rust - Ed25519 signing, SecQR
- **Notification Service** (`services/notification-service/`): Python/FastAPI - FCM, SMS, WhatsApp
- **Wallet Service** (`services/wallet-service/`): Go - Double-entry ledger
- **Cargo Service** (`services/cargo-service/`): Node.js/TypeScript - Parcel logistics
- **Admin Service** (`services/admin-service/`): NestJS - Fleet, pricing, audit

### Infrastructure
- **Docker Compose** (`infra/docker/`): Local development
- **Kubernetes** (`infra/k8s/`): Production deployment
- **Terraform** (`infra/terraform/`): AWS infrastructure
- **Database** (`database/migrations/`): PostgreSQL DDL

## Admin Capabilities

The Super-Admin portal provides full control over:

1. **Operator Registration**: Register bus companies with KYC, commission rates, settlement accounts
2. **Fleet Management**: Add/edit/delete buses with VIN, chassis, insurance tracking
3. **Visual Seat Designer**: Drag-and-drop seat layout configuration
4. **Route Management**: Create routes with GIS waypoints, cross-border flags
5. **Fare Configuration**: 
   - Manual fare entry per route/bus-type/currency
   - Dynamic surge pricing rules
   - Peak hour multipliers
   - External API integration for real-time fare fetching
6. **Schedule Generation**: Recurring trip schedules with automatic seat inventory
7. **Financial Clearing**: Commission tracking, automated payouts
8. **Audit Vault**: Immutable admin action logging with cryptographic signatures

## Getting Started

See `docs/README.md` for full deployment instructions.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Flutter     │  │ Next.js     │  │ Next.js Admin       │  │
│  │ Passenger   │  │ Passenger   │  │ Portal (WebAuthn)   │  │
│  │ App         │  │ Web Portal  │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      API GATEWAY (Kong)                      │
│              Rate Limiting │ CORS │ Auth │ mTLS              │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    SERVICE MESH (Istio)                        │
│                         mTLS Enforced                        │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                     MICROSERVICES LAYER                      │
│  Auth │ Booking │ Inventory │ Payment │ Ticket │ Notify   │
│  Wallet │ Cargo │ Admin                                    │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      DATA LAYER                                │
│  Aurora PostgreSQL │ ElastiCache Redis │ MSK Kafka          │
│  OpenSearch │ DynamoDB │ S3                                    │
└─────────────────────────────────────────────────────────────┘
```

## License
Proprietary - OmniBus EA Ltd. All rights reserved.
