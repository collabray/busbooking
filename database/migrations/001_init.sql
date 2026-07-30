-- OmniBus EA Production Database Schema
-- Run this against Amazon Aurora PostgreSQL Serverless v2

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- 1. OPERATORS (Bus Companies registered via Admin Panel)
-- =====================================================
CREATE TABLE operators (
    operator_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name VARCHAR(150) NOT NULL,
    legal_name VARCHAR(150),
    registration_number VARCHAR(50) UNIQUE,
    tax_id VARCHAR(50),
    country_code VARCHAR(3) NOT NULL CHECK (country_code IN ('KEN', 'UGA', 'TZA', 'RWA', 'BDI', 'SSD')),
    contact_email VARCHAR(100) UNIQUE NOT NULL,
    contact_phone VARCHAR(20) UNIQUE NOT NULL,
    physical_address TEXT,
    commission_rate NUMERIC(5,2) NOT NULL DEFAULT 8.00 CHECK (commission_rate >= 0 AND commission_rate <= 50),
    settlement_account JSONB DEFAULT '{}',
    api_endpoint VARCHAR(500),
    api_key_hash VARCHAR(256),
    api_enabled BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'BLACKLISTED')),
    verified_by UUID,
    verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_operators_country ON operators(country_code);
CREATE INDEX idx_operators_status ON operators(status);
CREATE INDEX idx_operators_email ON operators(contact_email);

-- =====================================================
-- 2. BUSES (Managed by Admin / Operator)
-- =====================================================
CREATE TABLE buses (
    bus_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    operator_id UUID NOT NULL REFERENCES operators(operator_id) ON DELETE RESTRICT,
    registration_number VARCHAR(30) UNIQUE NOT NULL,
    chassis_number VARCHAR(50) UNIQUE,
    engine_number VARCHAR(50),
    vin VARCHAR(50) UNIQUE,
    capacity INT NOT NULL CHECK (capacity > 0 AND capacity <= 80),
    bus_type VARCHAR(30) NOT NULL CHECK (bus_type IN ('STANDARD', 'EXECUTIVE', 'VIP', 'LUXURY', 'DOUBLE_DECKER')),
    seat_layout_json JSONB NOT NULL DEFAULT '{"rows":10,"columns":4,"seats":[]}'::jsonb,
    amenities JSONB NOT NULL DEFAULT '{"wifi":false,"ac":false,"charger":false,"entertainment":false,"refreshments":false,"toilet":false}'::jsonb,
    insurance_expiry DATE,
    last_inspection_date DATE,
    gps_unit_id VARCHAR(50),
    status VARCHAR(20) NOT NULL DEFAULT 'OPERATIONAL' CHECK (status IN ('OPERATIONAL', 'MAINTENANCE', 'RETIRED', 'SUSPENDED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID NOT NULL,
    updated_by UUID
);

CREATE INDEX idx_buses_operator ON buses(operator_id);
CREATE INDEX idx_buses_status ON buses(status);
CREATE INDEX idx_buses_reg ON buses(registration_number);

-- =====================================================
-- 3. ROUTES
-- =====================================================
CREATE TABLE routes (
    route_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    origin_city VARCHAR(100) NOT NULL,
    origin_country VARCHAR(3) NOT NULL,
    destination_city VARCHAR(100) NOT NULL,
    destination_country VARCHAR(3) NOT NULL,
    origin_coordinates POINT NOT NULL,
    destination_coordinates POINT NOT NULL,
    distance_km NUMERIC(8,2),
    waypoints_json JSONB,
    is_cross_border BOOLEAN NOT NULL DEFAULT FALSE,
    kyc_required BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_routes_search ON routes(origin_city, destination_city, status);
CREATE INDEX idx_routes_crossborder ON routes(is_cross_border);

-- =====================================================
-- 4. FARE RULES (Admin-configurable pricing)
-- =====================================================
CREATE TABLE fare_rules (
    fare_rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES routes(route_id) ON DELETE CASCADE,
    bus_type VARCHAR(30) NOT NULL,
    base_price_kes NUMERIC(10,2) NOT NULL CHECK (base_price_kes >= 0),
    base_price_ugx NUMERIC(10,2) NOT NULL CHECK (base_price_ugx >= 0),
    base_price_tzs NUMERIC(10,2) NOT NULL CHECK (base_price_tzs >= 0),
    base_price_usd NUMERIC(10,2) NOT NULL CHECK (base_price_usd >= 0),
    surge_multiplier_min NUMERIC(3,2) NOT NULL DEFAULT 1.00,
    surge_multiplier_max NUMERIC(3,2) NOT NULL DEFAULT 3.00,
    demand_threshold INT NOT NULL DEFAULT 70,
    peak_hours JSONB DEFAULT '[{"start":"06:00","end":"09:00","multiplier":1.2},{"start":"17:00","end":"20:00","multiplier":1.15}]'::jsonb,
    weekend_multiplier NUMERIC(3,2) DEFAULT 1.00,
    holiday_multiplier NUMERIC(3,2) DEFAULT 1.00,
    child_discount_percent NUMERIC(5,2) DEFAULT 0,
    senior_discount_percent NUMERIC(5,2) DEFAULT 0,
    luggage_included_kg NUMERIC(5,2) DEFAULT 20.00,
    extra_luggage_rate_per_kg NUMERIC(8,2) DEFAULT 100.00,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'EXPIRED')),
    created_by UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_fare_rules_route ON fare_rules(route_id, bus_type, status);
CREATE INDEX idx_fare_rules_effective ON fare_rules(effective_from, effective_to);

-- =====================================================
-- 5. SCHEDULES / TRIPS
-- =====================================================
CREATE TABLE schedules (
    schedule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bus_id UUID NOT NULL REFERENCES buses(bus_id) ON DELETE RESTRICT,
    route_id UUID NOT NULL REFERENCES routes(route_id) ON DELETE RESTRICT,
    fare_rule_id UUID REFERENCES fare_rules(fare_rule_id),
    departure_time TIMESTAMP WITH TIME ZONE NOT NULL,
    estimated_arrival_time TIMESTAMP WITH TIME ZONE NOT NULL,
    actual_departure_time TIMESTAMP WITH TIME ZONE,
    actual_arrival_time TIMESTAMP WITH TIME ZONE,
    base_price_usd NUMERIC(10,2) NOT NULL,
    dynamic_price_usd NUMERIC(10,2),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    available_seats INT NOT NULL,
    booked_seats INT NOT NULL DEFAULT 0,
    cargo_capacity_kg NUMERIC(8,2) DEFAULT 500.00,
    cargo_reserved_kg NUMERIC(8,2) DEFAULT 0.00,
    status VARCHAR(20) NOT NULL DEFAULT 'SCHEDULED' CHECK (status IN ('SCHEDULED', 'BOARDING', 'DEPARTED', 'ARRIVED', 'CANCELLED', 'DELAYED')),
    delay_minutes INT DEFAULT 0,
    cancellation_reason TEXT,
    created_by UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_schedules_search ON schedules(route_id, departure_time, status);
CREATE INDEX idx_schedules_bus ON schedules(bus_id, departure_time);
CREATE INDEX idx_schedules_departure ON schedules(departure_time, status);

-- =====================================================
-- 6. BOOKINGS
-- =====================================================
CREATE TABLE bookings (
    booking_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pnr_code VARCHAR(10) UNIQUE NOT NULL,
    user_id UUID NOT NULL,
    schedule_id UUID NOT NULL REFERENCES schedules(schedule_id) ON DELETE RESTRICT,
    seat_number VARCHAR(10) NOT NULL,
    passenger_name VARCHAR(150) NOT NULL,
    passenger_phone VARCHAR(20),
    passenger_email VARCHAR(100),
    passenger_gender VARCHAR(10),
    passenger_age_group VARCHAR(20) DEFAULT 'ADULT',
    passenger_id_passport VARCHAR(50),
    passenger_id_type VARCHAR(20),
    passenger_nationality VARCHAR(3),
    id_document_url TEXT,
    amount_paid NUMERIC(10,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    payment_method VARCHAR(30),
    payment_ref VARCHAR(100),
    payment_status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED', 'PARTIAL')),
    booking_status VARCHAR(20) NOT NULL DEFAULT 'HELD' CHECK (booking_status IN ('HELD', 'BOOKED', 'CANCELLED', 'NO_SHOW', 'BOARDED', 'COMPLETED')),
    lock_expires_at TIMESTAMP WITH TIME ZONE,
    cancellation_reason TEXT,
    refund_amount NUMERIC(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_bookings_pnr ON bookings(pnr_code);
CREATE INDEX idx_bookings_user ON bookings(user_id, created_at DESC);
CREATE INDEX idx_bookings_schedule ON bookings(schedule_id, booking_status);
CREATE INDEX idx_bookings_status ON bookings(booking_status, created_at);

-- =====================================================
-- 7. USERS (Auth Service)
-- =====================================================
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    phone_encrypted TEXT,
    encryption_key TEXT,
    legal_name VARCHAR(150),
    legal_name_encrypted TEXT,
    name_encryption_key TEXT,
    gender VARCHAR(10) CHECK (gender IN ('MALE', 'FEMALE', 'OTHER')),
    nationality VARCHAR(3),
    passport_number VARCHAR(50),
    passport_encrypted TEXT,
    passport_encryption_key TEXT,
    id_document_url TEXT,
    id_document_verified_at TIMESTAMP WITH TIME ZONE,
    kyc_status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (kyc_status IN ('PENDING', 'SUBMITTED', 'UNDER_REVIEW', 'VERIFIED', 'REJECTED')),
    kyc_tier INT NOT NULL DEFAULT 0 CHECK (kyc_tier BETWEEN 0 AND 3),
    kyc_rejection_reason TEXT,
    email VARCHAR(100),
    date_of_birth DATE,
    preferred_language VARCHAR(5) DEFAULT 'en-KE',
    preferred_currency VARCHAR(3) DEFAULT 'KES',
    fcm_token TEXT,
    last_login_at TIMESTAMP WITH TIME ZONE,
    login_attempts INT DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DEACTIVATED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_users_kyc ON users(kyc_status);

-- =====================================================
-- 8. ADMIN USERS
-- =====================================================
CREATE TABLE admin_users (
    admin_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(100) UNIQUE NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    role VARCHAR(30) NOT NULL CHECK (role IN ('SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_ADMIN', 'SUPPORT_AGENT')),
    department VARCHAR(50),
    webauthn_credential_id VARCHAR(200),
    webauthn_public_key BYTEA,
    totp_secret VARCHAR(100),
    ip_whitelist TEXT[],
    last_login_ip INET,
    last_login_at TIMESTAMP WITH TIME ZONE,
    failed_login_attempts INT DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'TERMINATED')),
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_admin_email ON admin_users(email);
CREATE INDEX idx_admin_status ON admin_users(status);

-- =====================================================
-- 9. ADMIN AUDIT LOG
-- =====================================================
CREATE TABLE admin_audit_log (
    audit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id UUID NOT NULL REFERENCES admin_users(admin_id),
    action_type VARCHAR(50) NOT NULL,
    resource_table VARCHAR(50) NOT NULL,
    resource_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET NOT NULL,
    user_agent TEXT,
    session_id VARCHAR(100),
    approval_required BOOLEAN DEFAULT FALSE,
    approved_by UUID,
    approved_at TIMESTAMP WITH TIME ZONE,
    cryptographic_signature VARCHAR(256),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_admin ON admin_audit_log(admin_id, created_at DESC);
CREATE INDEX idx_audit_resource ON admin_audit_log(resource_table, resource_id);
CREATE INDEX idx_audit_action ON admin_audit_log(action_type, created_at DESC);

-- =====================================================
-- 10. PAYMENT TRANSACTIONS
-- =====================================================
CREATE TABLE payment_transactions (
    transaction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_ref VARCHAR(64) UNIQUE NOT NULL,
    booking_id UUID REFERENCES bookings(booking_id),
    cargo_id UUID,
    provider VARCHAR(20) NOT NULL CHECK (provider IN ('MPESA', 'AIRTEL_MONEY', 'TIGO_PESA', 'MTN', 'DPO', 'BANK_TRANSFER', 'CASH')),
    provider_transaction_id VARCHAR(100),
    amount NUMERIC(15,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'PAID', 'FAILED', 'REFUNDED', 'CANCELLED')),
    provider_response JSONB,
    phone_number VARCHAR(20),
    bank_account VARCHAR(50),
    completed_at TIMESTAMP WITH TIME ZONE,
    idempotency_key VARCHAR(256) UNIQUE,
    retry_count INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_payments_ref ON payment_transactions(payment_ref);
CREATE INDEX idx_payments_booking ON payment_transactions(booking_id);
CREATE INDEX idx_payments_status ON payment_transactions(status, created_at);

-- =====================================================
-- 11. TICKETS
-- =====================================================
CREATE TABLE tickets (
    ticket_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pnr VARCHAR(10) UNIQUE NOT NULL REFERENCES bookings(pnr_code),
    booking_id UUID NOT NULL REFERENCES bookings(booking_id),
    payload_json JSONB NOT NULL,
    signature TEXT NOT NULL,
    public_key_id VARCHAR(50) NOT NULL,
    qr_data TEXT,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    scanned_at TIMESTAMP WITH TIME ZONE,
    scanned_by UUID,
    scan_location VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'VALID' CHECK (status IN ('VALID', 'USED', 'EXPIRED', 'CANCELLED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tickets_pnr ON tickets(pnr);
CREATE INDEX idx_tickets_status ON tickets(status, expires_at);

-- =====================================================
-- 12. SIGNING KEYS
-- =====================================================
CREATE TABLE signing_keys (
    key_id VARCHAR(50) PRIMARY KEY,
    algorithm VARCHAR(20) NOT NULL DEFAULT 'Ed25519',
    private_key BYTEA NOT NULL,
    public_key BYTEA NOT NULL,
    kms_key_id VARCHAR(200),
    rotated_from VARCHAR(50),
    expires_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'REVOKED', 'EXPIRED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 13. WALLETS & LEDGER
-- =====================================================
CREATE TABLE wallets (
    wallet_id VARCHAR(50) PRIMARY KEY,
    entity_id UUID NOT NULL,
    entity_type VARCHAR(20) NOT NULL CHECK (entity_type IN ('OPERATOR', 'PLATFORM', 'DRIVER', 'AGENT')),
    balance NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
    hold_balance NUMERIC(15,2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'FROZEN', 'CLOSED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ledger_entries (
    entry_id VARCHAR(50) PRIMARY KEY,
    wallet_id VARCHAR(50) NOT NULL REFERENCES wallets(wallet_id),
    transaction_id VARCHAR(100) NOT NULL,
    entry_type VARCHAR(10) NOT NULL CHECK (entry_type IN ('DEBIT', 'CREDIT', 'HOLD', 'RELEASE')),
    amount NUMERIC(15,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    balance_after NUMERIC(15,2) NOT NULL,
    description TEXT NOT NULL,
    reference_type VARCHAR(30),
    reference_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_ledger_wallet ON ledger_entries(wallet_id, created_at DESC);
CREATE INDEX idx_ledger_txn ON ledger_entries(transaction_id);

-- =====================================================
-- 14. CARGO BOOKINGS
-- =====================================================
CREATE TABLE cargo_bookings (
    cargo_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tracking_number VARCHAR(30) UNIQUE NOT NULL,
    schedule_id UUID NOT NULL REFERENCES schedules(schedule_id),
    sender_name VARCHAR(150) NOT NULL,
    sender_phone VARCHAR(20) NOT NULL,
    sender_id_number VARCHAR(50),
    receiver_name VARCHAR(150) NOT NULL,
    receiver_phone VARCHAR(20) NOT NULL,
    receiver_station VARCHAR(100) NOT NULL,
    weight_kg NUMERIC(8,2) NOT NULL CHECK (weight_kg > 0 AND weight_kg <= 500),
    length_cm NUMERIC(6,2) NOT NULL,
    width_cm NUMERIC(6,2) NOT NULL,
    height_cm NUMERIC(6,2) NOT NULL,
    volume_cm3 NUMERIC(12,2) GENERATED ALWAYS AS (length_cm * width_cm * height_cm) STORED,
    description TEXT NOT NULL,
    declared_value NUMERIC(12,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    cargo_fee NUMERIC(12,2) NOT NULL,
    insurance_fee NUMERIC(12,2) DEFAULT 0,
    fragile BOOLEAN NOT NULL DEFAULT FALSE,
    perishable BOOLEAN NOT NULL DEFAULT FALSE,
    hazardous BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'CHECKED_IN', 'LOADED', 'IN_TRANSIT', 'ARRIVED', 'DELIVERED', 'RETURNED', 'LOST')),
    payment_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    delivery_signature_url TEXT,
    delivery_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_cargo_tracking ON cargo_bookings(tracking_number);
CREATE INDEX idx_cargo_schedule ON cargo_bookings(schedule_id);

-- =====================================================
-- 15. CARGO TRACKING EVENTS
-- =====================================================
CREATE TABLE cargo_tracking_events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cargo_id UUID NOT NULL REFERENCES cargo_bookings(cargo_id),
    status VARCHAR(20) NOT NULL,
    location VARCHAR(100) NOT NULL,
    lat NUMERIC(10,8),
    lng NUMERIC(11,8),
    notes TEXT,
    recorded_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_cargo_events ON cargo_tracking_events(cargo_id, created_at DESC);

-- =====================================================
-- 16. PAYOUTS
-- =====================================================
CREATE TABLE payouts (
    payout_id VARCHAR(50) PRIMARY KEY,
    wallet_id VARCHAR(50) NOT NULL REFERENCES wallets(wallet_id),
    amount NUMERIC(15,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    method VARCHAR(20) NOT NULL CHECK (method IN ('MOBILE_MONEY', 'RTGS', 'SWIFT', 'CHEQUE')),
    destination_account VARCHAR(100) NOT NULL,
    destination_bank VARCHAR(100),
    destination_name VARCHAR(150),
    reference VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'REVERSED')),
    processed_at TIMESTAMP WITH TIME ZONE,
    processed_by UUID,
    failure_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_payouts_wallet ON payouts(wallet_id, created_at DESC);

-- =====================================================
-- 17. EXTERNAL API INTEGRATIONS (for real bus company APIs)
-- =====================================================
CREATE TABLE external_api_configs (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    operator_id UUID NOT NULL REFERENCES operators(operator_id) ON DELETE CASCADE,
    api_name VARCHAR(50) NOT NULL,
    api_base_url VARCHAR(500) NOT NULL,
    api_version VARCHAR(20),
    auth_type VARCHAR(20) NOT NULL CHECK (auth_type IN ('API_KEY', 'OAUTH2', 'BASIC_AUTH', 'HMAC')),
    auth_config JSONB NOT NULL,
    endpoints JSONB NOT NULL DEFAULT '{}',
    rate_limit_per_minute INT DEFAULT 60,
    timeout_seconds INT DEFAULT 30,
    retry_policy JSONB DEFAULT '{"max_retries":3,"backoff_ms":1000}'::jsonb,
    last_synced_at TIMESTAMP WITH TIME ZONE,
    sync_enabled BOOLEAN DEFAULT FALSE,
    sync_interval_minutes INT DEFAULT 60,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_external_api_operator ON external_api_configs(operator_id);

-- =====================================================
-- 18. EXTERNAL FARE SYNC LOG
-- =====================================================
CREATE TABLE external_fare_sync_log (
    sync_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_id UUID NOT NULL REFERENCES external_api_configs(config_id),
    route_id UUID REFERENCES routes(route_id),
    raw_response JSONB,
    fares_parsed INT DEFAULT 0,
    fares_updated INT DEFAULT 0,
    fares_failed INT DEFAULT 0,
    error_message TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'SUCCESS',
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    duration_ms INT
);

-- =====================================================
-- 19. SEAT LAYOUT TEMPLATES
-- =====================================================
CREATE TABLE seat_layout_templates (
    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL,
    description TEXT,
    bus_type VARCHAR(30) NOT NULL,
    rows INT NOT NULL,
    columns INT NOT NULL,
    layout_json JSONB NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    created_by UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- TRIGGERS FOR UPDATED_AT
-- =====================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_operators_updated_at BEFORE UPDATE ON operators FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_buses_updated_at BEFORE UPDATE ON buses FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_routes_updated_at BEFORE UPDATE ON routes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_schedules_updated_at BEFORE UPDATE ON schedules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_fare_rules_updated_at BEFORE UPDATE ON fare_rules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_admin_users_updated_at BEFORE UPDATE ON admin_users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_payment_transactions_updated_at BEFORE UPDATE ON payment_transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_cargo_bookings_updated_at BEFORE UPDATE ON cargo_bookings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_external_api_configs_updated_at BEFORE UPDATE ON external_api_configs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_audit_log ENABLE ROW LEVEL SECURITY;

-- Users can only see their own bookings
CREATE POLICY user_bookings_policy ON bookings
    FOR ALL TO omnibus_app
    USING (user_id = current_setting('app.current_user_id')::UUID);

-- Audit logs restricted by admin role
CREATE POLICY admin_audit_policy ON admin_audit_log
    FOR SELECT TO omnibus_app
    USING (admin_id = current_setting('app.current_admin_id')::UUID OR
           current_setting('app.current_admin_role') = 'SUPER_ADMIN');
