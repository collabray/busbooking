use axum::{
    extract::{State, Path, Query},
    Json,
    http::StatusCode,
};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use std::sync::Arc;
use uuid::Uuid;
use crate::{AppState, models::{Route, Schedule, Bus, SeatLayout}};
use tracing::{info, error};

#[derive(Debug, Deserialize)]
pub struct CreateRouteRequest {
    pub origin_city: String,
    pub destination_city: String,
    pub origin_lat: f64,
    pub origin_lng: f64,
    pub destination_lat: f64,
    pub destination_lng: f64,
    pub waypoints: Option<Vec<Waypoint>>,
    pub is_cross_border: bool,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct Waypoint {
    pub name: String,
    pub lat: f64,
    pub lng: f64,
    pub stop_duration_minutes: i32,
}

#[derive(Debug, Deserialize)]
pub struct SearchRoutesQuery {
    pub origin: String,
    pub destination: String,
    pub date: String,
}

pub async fn create_route(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CreateRouteRequest>,
) -> Result<Json<Route>, StatusCode> {
    let route_id = Uuid::new_v4();
    let waypoints = req.waypoints.map(|w| serde_json::to_value(w).unwrap());

    let result = sqlx::query_as::<_, Route>(
        r#"INSERT INTO routes (route_id, origin_city, destination_city, origin_coordinates, destination_coordinates, waypoints_json, is_cross_border, created_at)
         VALUES ($1, $2, $3, point($4, $5), point($6, $7), $8, $9, NOW())
         RETURNING *"#
    )
    .bind(route_id)
    .bind(&req.origin_city)
    .bind(&req.destination_city)
    .bind(req.origin_lat)
    .bind(req.origin_lng)
    .bind(req.destination_lat)
    .bind(req.destination_lng)
    .bind(waypoints)
    .bind(req.is_cross_border)
    .fetch_one(&state.db)
    .await;

    match result {
        Ok(route) => {
            info!("Route created: {}", route.route_id);
            Ok(Json(route))
        }
        Err(e) => {
            error!("Failed to create route: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

pub async fn search_routes(
    State(state): State<Arc<AppState>>,
    Query(query): Query<SearchRoutesQuery>,
) -> Result<Json<Vec<ScheduleWithRoute>>, StatusCode> {
    let search_date = query.date.parse::<chrono::NaiveDate>().map_err(|_| StatusCode::BAD_REQUEST)?;
    let start = search_date.and_hms_opt(0, 0, 0).unwrap();
    let end = search_date.and_hms_opt(23, 59, 59).unwrap();

    let rows = sqlx::query_as::<_, ScheduleWithRoute>(
        r#"SELECT s.schedule_id, s.bus_id, s.route_id, s.departure_time, s.estimated_arrival_time,
                s.base_price_usd, s.status, s.created_at,
                r.origin_city, r.destination_city, r.is_cross_border,
                b.registration_number, b.capacity, b.bus_type, b.amenities
         FROM schedules s
         JOIN routes r ON s.route_id = r.route_id
         JOIN buses b ON s.bus_id = b.bus_id
         WHERE r.origin_city ILIKE $1 AND r.destination_city ILIKE $2
         AND s.departure_time BETWEEN $3 AND $4
         AND s.status = 'SCHEDULED'
         ORDER BY s.departure_time"#
    )
    .bind(format!("%{}%", query.origin))
    .bind(format!("%{}%", query.destination))
    .bind(start)
    .bind(end)
    .fetch_all(&state.db)
    .await;

    match rows {
        Ok(schedules) => Ok(Json(schedules)),
        Err(e) => {
            error!("Search failed: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

pub async fn get_route(
    State(state): State<Arc<AppState>>,
    Path(id): Path<Uuid>,
) -> Result<Json<Route>, StatusCode> {
    let route = sqlx::query_as::<_, Route>("SELECT * FROM routes WHERE route_id = $1")
        .bind(id)
        .fetch_one(&state.db)
        .await
        .map_err(|_| StatusCode::NOT_FOUND)?;
    Ok(Json(route))
}

#[derive(Debug, Deserialize)]
pub struct CreateScheduleRequest {
    pub bus_id: Uuid,
    pub route_id: Uuid,
    pub departure_time: chrono::DateTime<chrono::Utc>,
    pub estimated_arrival_time: chrono::DateTime<chrono::Utc>,
    pub base_price_usd: f64,
}

pub async fn create_schedule(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CreateScheduleRequest>,
) -> Result<Json<Schedule>, StatusCode> {
    let schedule_id = Uuid::new_v4();
    let schedule = sqlx::query_as::<_, Schedule>(
        r#"INSERT INTO schedules (schedule_id, bus_id, route_id, departure_time, estimated_arrival_time, base_price_usd, status, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, 'SCHEDULED', NOW())
         RETURNING *"#
    )
    .bind(schedule_id)
    .bind(req.bus_id)
    .bind(req.route_id)
    .bind(req.departure_time)
    .bind(req.estimated_arrival_time)
    .bind(req.base_price_usd)
    .fetch_one(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(schedule))
}

pub async fn get_schedule(
    State(state): State<Arc<AppState>>,
    Path(id): Path<Uuid>,
) -> Result<Json<Schedule>, StatusCode> {
    let schedule = sqlx::query_as::<_, Schedule>("SELECT * FROM schedules WHERE schedule_id = $1")
        .bind(id)
        .fetch_one(&state.db)
        .await
        .map_err(|_| StatusCode::NOT_FOUND)?;
    Ok(Json(schedule))
}

pub async fn get_seat_layout(
    State(state): State<Arc<AppState>>,
    Path(id): Path<Uuid>,
) -> Result<Json<SeatLayout>, StatusCode> {
    let bus = sqlx::query_as::<_, Bus>("SELECT * FROM buses WHERE bus_id = $1")
        .bind(id)
        .fetch_one(&state.db)
        .await
        .map_err(|_| StatusCode::NOT_FOUND)?;

    let layout: SeatLayout = serde_json::from_value(bus.seat_layout_json)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(Json(layout))
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct ScheduleWithRoute {
    pub schedule_id: Uuid,
    pub bus_id: Uuid,
    pub route_id: Uuid,
    pub departure_time: chrono::DateTime<chrono::Utc>,
    pub estimated_arrival_time: chrono::DateTime<chrono::Utc>,
    pub base_price_usd: f64,
    pub status: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub origin_city: String,
    pub destination_city: String,
    pub is_cross_border: bool,
    pub registration_number: String,
    pub capacity: i32,
    pub bus_type: String,
    pub amenities: serde_json::Value,
}
