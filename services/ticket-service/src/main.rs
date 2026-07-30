use axum::{
    routing::{get, post},
    Router, Json, extract::State, http::StatusCode,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::net::TcpListener;
use tracing::{info, error};
use chrono::{DateTime, Utc, Duration};
use uuid::Uuid;
use ring::signature::{Ed25519KeyPair, KeyPair, UnparsedPublicKey, ED25519};
use redis::aio::ConnectionManager;
use sqlx::PgPool;

mod crypto;

#[derive(Clone)]
struct AppState {
    db: PgPool,
    redis: ConnectionManager,
    signing_key: Arc<Ed25519KeyPair>,
}

#[derive(Debug, Serialize, Deserialize)]
struct TicketPayload {
    pnr: String,
    bus_id: Uuid,
    seat_no: String,
    passenger_hash: String,
    expiry_timestamp: DateTime<Utc>,
    issued_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GenerateTicketRequest {
    pnr: String,
    bus_id: Uuid,
    seat_no: String,
    passenger_name: String,
    passenger_phone: String,
}

#[derive(Debug, Serialize)]
struct TicketResponse {
    pnr: String,
    qr_data: String,
    signature: String,
    public_key: String,
    expires_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
struct VerifyRequest {
    qr_data: String,
    signature: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let redis_url = std::env::var("REDIS_URL").unwrap_or_else(|_| "redis://localhost:6379".to_string());

    let pool = PgPool::connect(&database_url).await?;
    let redis_client = redis::Client::open(redis_url)?;
    let redis_conn = ConnectionManager::new(redis_client).await?;

    let signing_key = crypto::load_or_create_signing_key(&pool).await?;

    let state = Arc::new(AppState {
        db: pool,
        redis: redis_conn,
        signing_key: Arc::new(signing_key),
    });

    let app = Router::new()
        .route("/health", get(health_check))
        .route("/api/v1/tickets/generate", post(generate_ticket))
        .route("/api/v1/tickets/verify", post(verify_ticket))
        .route("/api/v1/tickets/:pnr", get(get_ticket))
        .route("/api/v1/keys/public", get(get_public_key))
        .layer(tower_http::cors::CorsLayer::permissive())
        .with_state(state);

    let listener = TcpListener::bind("0.0.0.0:8080").await?;
    info!("Ticket Service listening on {}", listener.local_addr()?);
    axum::serve(listener, app).await?;
    Ok(())
}

async fn health_check() -> Json<serde_json::Value> {
    Json(serde_json::json!({"status": "healthy", "service": "ticket-service"}))
}

async fn generate_ticket(
    State(state): State<Arc<AppState>>,
    Json(req): Json<GenerateTicketRequest>,
) -> Result<Json<TicketResponse>, StatusCode> {
    let passenger_hash = crypto::hash_passenger(&req.passenger_name, &req.passenger_phone);
    let expiry = Utc::now() + Duration::hours(48);

    let payload = TicketPayload {
        pnr: req.pnr.clone(),
        bus_id: req.bus_id,
        seat_no: req.seat_no.clone(),
        passenger_hash,
        expiry_timestamp: expiry,
        issued_at: Utc::now(),
    };

    let payload_json = serde_json::to_string(&payload).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let signature = state.signing_key.sign(payload_json.as_bytes());
    let sig_b64 = base64::encode(signature.as_ref());

    let ticket_data = serde_json::json!({
        "payload": payload,
        "signature": sig_b64,
        "pub_key": base64::encode(state.signing_key.public_key().as_ref()),
    });
    let qr_data = base64::encode(ticket_data.to_string().as_bytes());

    // Store in DB
    let result = sqlx::query(
        "INSERT INTO tickets (ticket_id, pnr, payload_json, signature, expires_at, created_at) VALUES ($1, $2, $3, $4, $5, NOW())"
    )
    .bind(Uuid::new_v4())
    .bind(&req.pnr)
    .bind(&payload_json)
    .bind(&sig_b64)
    .bind(expiry)
    .execute(&state.db)
    .await;

    if let Err(e) = result {
        error!("Failed to store ticket: {}", e);
        return Err(StatusCode::INTERNAL_SERVER_ERROR);
    }

    Ok(Json(TicketResponse {
        pnr: req.pnr,
        qr_data,
        signature: sig_b64,
        public_key: base64::encode(state.signing_key.public_key().as_ref()),
        expires_at: expiry,
    }))
}

async fn verify_ticket(
    State(state): State<Arc<AppState>>,
    Json(req): Json<VerifyRequest>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let decoded = base64::decode(&req.qr_data).map_err(|_| StatusCode::BAD_REQUEST)?;
    let ticket_json: serde_json::Value = serde_json::from_slice(&decoded).map_err(|_| StatusCode::BAD_REQUEST)?;

    let payload = ticket_json["payload"].to_string();
    let signature = base64::decode(
        ticket_json["signature"].as_str().ok_or(StatusCode::BAD_REQUEST)?
    ).map_err(|_| StatusCode::BAD_REQUEST)?;

    let pub_key_bytes = base64::decode(
        ticket_json["pub_key"].as_str().ok_or(StatusCode::BAD_REQUEST)?
    ).map_err(|_| StatusCode::BAD_REQUEST)?;

    let public_key = UnparsedPublicKey::new(&ED25519, &pub_key_bytes);
    let valid = public_key.verify(payload.as_bytes(), &signature).is_ok();

    let payload_struct: TicketPayload = serde_json::from_str(&payload).map_err(|_| StatusCode::BAD_REQUEST)?;
    let expired = Utc::now() > payload_struct.expiry_timestamp;

    Ok(Json(serde_json::json!({
        "valid": valid && !expired,
        "signature_valid": valid,
        "expired": expired,
        "pnr": payload_struct.pnr,
        "bus_id": payload_struct.bus_id,
        "seat_no": payload_struct.seat_no,
    })))
}

async fn get_ticket(
    State(state): State<Arc<AppState>>,
    axum::extract::Path(pnr): axum::extract::Path<String>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let row = sqlx::query_as::<_, (String, String, DateTime<Utc>)>(
        "SELECT payload_json, signature, expires_at FROM tickets WHERE pnr = $1"
    )
    .bind(&pnr)
    .fetch_optional(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    match row {
        Some((payload, sig, exp)) => Ok(Json(serde_json::json!({
            "pnr": pnr,
            "payload": serde_json::from_str::<serde_json::Value>(&payload).unwrap_or_default(),
            "signature": sig,
            "expires_at": exp,
        }))),
        None => Err(StatusCode::NOT_FOUND),
    }
}

async fn get_public_key(State(state): State<Arc<AppState>>) -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "algorithm": "Ed25519",
        "public_key": base64::encode(state.signing_key.public_key().as_ref()),
    }))
}
