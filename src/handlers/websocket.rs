use axum::{
    extract::{
        ws::{WebSocket, WebSocketUpgrade},
        Path, State,
    },
    http::StatusCode,
    response::Response,
};
use sqlx::SqlitePool;
use std::sync::Arc;
use tracing::{error, info, warn};

use crate::{db, proxy::WsProxy};

/// WebSocket proxy handler
pub async fn websocket_handler(
    State(pool): State<Arc<SqlitePool>>,
    Path(session_id): Path<String>,
    ws: WebSocketUpgrade,
) -> Result<Response, StatusCode> {
    info!("Received WebSocket connection request: session_id={}", session_id);

    // 1. Query database to get session information
    let session = match db::get_session(&pool, &session_id).await {
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

    // 3. Convert HTTP URL to WebSocket URL
    let downstream_ws_url = convert_to_ws_url(&session.downstream_server_url);
    info!("Downstream WebSocket URL: {}", downstream_ws_url);

    // 4. Upgrade to WebSocket connection
    Ok(ws.on_upgrade(move |socket| handle_websocket(socket, downstream_ws_url)))
}

/// Handle WebSocket connection
async fn handle_websocket(socket: WebSocket, downstream_url: String) {
    info!("WebSocket connection upgraded");

    if let Err(e) = WsProxy::handle_connection(socket, &downstream_url).await {
        error!("WebSocket proxy error: {}", e);
    }

    info!("WebSocket connection closed");
}

/// Convert HTTP/HTTPS URL to WS/WSS URL
fn convert_to_ws_url(http_url: &str) -> String {
    if http_url.starts_with("https://") {
        http_url.replace("https://", "wss://")
    } else if http_url.starts_with("http://") {
        http_url.replace("http://", "ws://")
    } else {
        // If no protocol prefix, default to ws://
        format!("ws://{}", http_url)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_convert_to_ws_url() {
        assert_eq!(
            convert_to_ws_url("http://localhost:8080"),
            "ws://localhost:8080"
        );
        assert_eq!(
            convert_to_ws_url("https://example.com"),
            "wss://example.com"
        );
        assert_eq!(convert_to_ws_url("localhost:8080"), "ws://localhost:8080");
    }
}
