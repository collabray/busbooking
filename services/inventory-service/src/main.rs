use axum::{
    routing::{get, post},
    Router,
    Json,
    extract::{State, Path, Query},
    http::StatusCode,
};
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, postgres::PgPoolOptions};
use std::sync::Arc;
use tokio::net::TcpListener;
use tracing::{info, error};
use chrono::{DateTime, Utc};
use uuid::Uuid;
use redis::{aio::ConnectionManager, Client as RedisClient};
use opensearch::OpenSearch;

mod models;
mod routes;

#[derive(Clone)]
struct AppState {
    db: PgPool,
    redis: ConnectionManager,
    opensearch: OpenSearch,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    dotenvy::dotenv().ok();

    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");
    let redis_url = std::env::var("REDIS_URL")
        .expect("REDIS_URL must be set");
    let opensearch_url = std::env::var("OPENSEARCH_URL")
        .unwrap_or_else(|_| "http://localhost:9200".to_string());

    let pool = PgPoolOptions::new()
        .max_connections(100)
        .acquire_timeout(std::time::Duration::from_secs(5))
        .connect(&database_url)
        .await?;

    let redis_client = RedisClient::open(redis_url)?;
    let redis_conn = ConnectionManager::new(redis_client).await?;

    let opensearch = OpenSearch::default();

    let state = Arc::new(AppState {
        db: pool,
        redis: redis_conn,
        opensearch,
    });

    let app = Router::new()
        .route("/health", get(health_check))
        .route("/api/v1/routes", post(routes::create_route))
        .route("/api/v1/routes/search", get(routes::search_routes))
        .route("/api/v1/routes/:id", get(routes::get_route))
        .route("/api/v1/schedules", post(routes::create_schedule))
        .route("/api/v1/schedules/:id", get(routes::get_schedule))
        .route("/api/v1/buses/:id/seats", get(routes::get_seat_layout))
        .layer(tower_http::cors::CorsLayer::permissive())
        .layer(tower_http::trace::TraceLayer::new_for_http())
        .with_state(state);

    let listener = TcpListener::bind("0.0.0.0:8080").await?;
    info!("Inventory Service listening on {}", listener.local_addr()?);
    axum::serve(listener, app).await?;

    Ok(())
}

async fn health_check() -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "status": "healthy",
        "service": "inventory-service"
    }))
}
