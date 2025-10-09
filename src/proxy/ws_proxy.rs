use axum::extract::ws::{Message, WebSocket};
use futures_util::{SinkExt, StreamExt};
use tokio_tungstenite::{connect_async, tungstenite::Message as TungsteniteMessage};
use tracing::{error, info, warn};

/// WebSocket proxy
pub struct WsProxy;

impl WsProxy {
    /// Handle WebSocket connection, forwarding messages between client and downstream server
    pub async fn handle_connection(
        client_ws: WebSocket,
        downstream_url: &str,
    ) -> Result<(), WsProxyError> {
        info!("Establishing connection to downstream WebSocket: {}", downstream_url);

        // Connect to downstream WebSocket server
        let (downstream_ws, _) = connect_async(downstream_url)
            .await
            .map_err(|e| {
                error!("Failed to connect to downstream WebSocket: {}", e);
                WsProxyError::ConnectionFailed(e.to_string())
            })?;

        info!("Successfully connected to downstream WebSocket");

        let (mut downstream_write, mut downstream_read) = downstream_ws.split();
        let (mut client_write, mut client_read) = client_ws.split();

        // Task 1: Client -> Downstream server
        let client_to_downstream = async {
            while let Some(msg) = client_read.next().await {
                match msg {
                    Ok(Message::Text(buffer)) => {
                        info!("Client -> Downstream: Text message ({} bytes)", buffer.len());
                        if let Err(e) = downstream_write
                            .send(TungsteniteMessage::Text(buffer.to_string()))
                            .await
                        {
                            error!("Failed to forward text message to downstream: {}", e);
                            break;
                        }
                    }
                    Ok(Message::Binary(data)) => {
                        info!("Client -> Downstream: Binary message ({} bytes)", data.len());
                        if let Err(e) = downstream_write
                            .send(TungsteniteMessage::Binary(data.into()))
                            .await
                        {
                            error!("Failed to forward binary message to downstream: {}", e);
                            break;
                        }
                    }
                    Ok(Message::Ping(data)) => {
                        info!("Client -> Downstream: Ping");
                        if let Err(e) = downstream_write
                            .send(TungsteniteMessage::Ping(data.into()))
                            .await
                        {
                            error!("Failed to forward Ping to downstream: {}", e);
                            break;
                        }
                    }
                    Ok(Message::Pong(data)) => {
                        info!("Client -> Downstream: Pong");
                        if let Err(e) = downstream_write
                            .send(TungsteniteMessage::Pong(data.into()))
                            .await
                        {
                            error!("Failed to forward Pong to downstream: {}", e);
                            break;
                        }
                    }
                    Ok(Message::Close(_frame)) => {
                        info!("Client closed connection");
                        let _ = downstream_write.send(TungsteniteMessage::Close(None)).await;
                        break;
                    }
                    Err(e) => {
                        warn!("Failed to receive message from client: {}", e);
                        break;
                    }
                }
            }
        };

        // Task 2: Downstream server -> Client
        let downstream_to_client = async {
            while let Some(msg) = downstream_read.next().await {
                match msg {
                    Ok(TungsteniteMessage::Text(text)) => {
                        info!("Downstream -> Client: Text message ({} bytes)", text.len());
                        if let Err(e) = client_write.send(Message::Text(text.into())).await {
                            error!("Failed to forward text message to client: {}", e);
                            break;
                        }
                    }
                    Ok(TungsteniteMessage::Binary(data)) => {
                        info!("Downstream -> Client: Binary message ({} bytes)", data.len());
                        if let Err(e) = client_write.send(Message::Binary(data.into())).await {
                            error!("Failed to forward binary message to client: {}", e);
                            break;
                        }
                    }
                    Ok(TungsteniteMessage::Ping(data)) => {
                        info!("Downstream -> Client: Ping");
                        if let Err(e) = client_write.send(Message::Ping(data.into())).await {
                            error!("Failed to forward Ping to client: {}", e);
                            break;
                        }
                    }
                    Ok(TungsteniteMessage::Pong(data)) => {
                        info!("Downstream -> Client: Pong");
                        if let Err(e) = client_write.send(Message::Pong(data.into())).await {
                            error!("Failed to forward Pong to client: {}", e);
                            break;
                        }
                    }
                    Ok(TungsteniteMessage::Close(_)) => {
                        info!("Downstream server closed connection");
                        let _ = client_write.close().await;
                        break;
                    }
                    Ok(TungsteniteMessage::Frame(_)) => {
                        // Ignore raw frames
                    }
                    Err(e) => {
                        warn!("Failed to receive message from downstream: {}", e);
                        break;
                    }
                }
            }
        };

        // Run both tasks concurrently
        tokio::select! {
            _ = client_to_downstream => {
                info!("Client to downstream forwarding task ended");
            }
            _ = downstream_to_client => {
                info!("Downstream to client forwarding task ended");
            }
        }

        info!("WebSocket proxy connection closed");
        Ok(())
    }
}

/// WebSocket proxy error
#[derive(Debug, thiserror::Error)]
pub enum WsProxyError {
    #[error("Failed to connect to downstream WebSocket: {0}")]
    ConnectionFailed(String),
}

