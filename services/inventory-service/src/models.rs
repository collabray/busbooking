use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use uuid::Uuid;
use sqlx::FromRow;

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct Route {
    pub route_id: Uuid,
    pub origin_city: String,
    pub destination_city: String,
    pub origin_coordinates: String,
    pub destination_coordinates: String,
    pub waypoints_json: Option<serde_json::Value>,
    pub is_cross_border: bool,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct Schedule {
    pub schedule_id: Uuid,
    pub bus_id: Uuid,
    pub route_id: Uuid,
    pub departure_time: DateTime<Utc>,
    pub estimated_arrival_time: DateTime<Utc>,
    pub base_price_usd: f64,
    pub status: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct Bus {
    pub bus_id: Uuid,
    pub operator_id: Uuid,
    pub registration_number: String,
    pub chassis_number: Option<String>,
    pub capacity: i32,
    pub bus_type: String,
    pub seat_layout_json: serde_json::Value,
    pub amenities: serde_json::Value,
    pub status: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SeatLayout {
    pub rows: i32,
    pub columns: i32,
    pub seats: Vec<Seat>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Seat {
    pub number: String,
    pub row: i32,
    pub col: i32,
    pub seat_type: String,
    pub attributes: Vec<String>,
}
