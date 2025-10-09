use axum::{
    body::Bytes,
    extract::{Path, RawQuery, State},
    http::{Method, StatusCode},
    response::{IntoResponse, Response},
};
use sqlx::SqlitePool;
use std::sync::Arc;
use tracing::{error, warn};

use crate::{db, proxy::HttpProxy};

/// HTTP/HTTPS proxy handler
pub async fn http_proxy_handler(
    State(state): State<Arc<AppState>>,
    Path((session_id, path)): Path<(String, String)>,
    RawQuery(query): RawQuery,
    method: Method,
    headers: axum::http::HeaderMap,
    body: Bytes,
) -> Result<Response, StatusCode> {
    // 1. Query database to get session information
    let session = match db::get_session(&state.pool, &session_id).await {
        Ok(s) => s,
        Err(e) => {
            warn!("Session not found: {} - {}", session_id, e);
            return Err(StatusCode::NOT_FOUND);
        }
    };

    // 2. Check downstream server status
    if !session.is_available() {
        error!(
            "Downstream server unavailable: {} (status: {})",
            session_id, session.downstream_server_status
        );
        return Err(StatusCode::SERVICE_UNAVAILABLE);
    }

    // 3. Construct full path with query string
    let full_path = if path.is_empty() {
        "/".to_string()
    } else if path.starts_with('/') {
        path
    } else {
        format!("/{}", path)
    };

    // Append query string if present
    let full_path_with_query = if let Some(q) = query {
        format!("{}?{}", full_path, q)
    } else {
        full_path
    };

    // 4. Forward request
    match state
        .http_proxy
        .forward_request(
            &session.downstream_server_url,
            &full_path_with_query,
            method,
            headers,
            body,
        )
        .await
    {
        Ok(response) => Ok(response),
        Err(e) => {
            error!("Failed to forward request: {}", e);
            Err(StatusCode::BAD_GATEWAY)
        }
    }
}

/// Health check endpoint
pub async fn health_check() -> impl IntoResponse {
    (StatusCode::OK, "OK")
}

/// Application state
pub struct AppState {
    pub pool: SqlitePool,
    pub http_proxy: HttpProxy,
}
