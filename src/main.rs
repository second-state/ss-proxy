use axum::{
    Router,
    routing::{any, get},
};
use clap::Parser;
use std::{sync::Arc, time::Duration};
use tower_http::trace::TraceLayer;
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod config;
mod db;
mod handlers;
mod models;
mod proxy;

use config::Config;
use handlers::{AppState, health_check, http_proxy_handler, websocket_handler};
use proxy::HttpProxy;

/// SS Proxy - HTTP/HTTPS/WebSocket Proxy Server
#[derive(Parser, Debug)]
#[command(name = "ss-proxy")]
#[command(author, version, about, long_about = None)]
pub struct CliArgs {
    /// Proxy server listening address
    #[arg(short = 'H', long, default_value = "0.0.0.0", env = "SS_PROXY_HOST")]
    pub host: String,

    /// Proxy server listening port
    #[arg(short, long, default_value = "8080", env = "SS_PROXY_PORT")]
    pub port: u16,

    /// Database file path (supports relative and absolute paths)
    #[arg(short, long, default_value = "./sessions.db", env = "SS_PROXY_DB_PATH")]
    pub db_path: String,

    /// Request timeout in seconds
    #[arg(short, long, default_value = "30", env = "SS_PROXY_TIMEOUT")]
    pub timeout: u64,

    /// Log level (trace, debug, info, warn, error)
    #[arg(short, long, default_value = "info", env = "SS_PROXY_LOG_LEVEL")]
    pub log_level: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Parse command line arguments
    let cli_args = CliArgs::parse();
    let log_level = cli_args.log_level.clone();

    // Initialize logging with CLI-specified log level
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                format!("ss_proxy={},tower_http={}", log_level, log_level).into()
            }),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    info!("🚀 Starting ss-proxy server");

    // Create configuration from CLI arguments
    let config = Config::from(cli_args);
    info!("Configuration: {:?}", config);

    // Create database connection pool
    let pool = db::create_pool(&config.database_url()).await?;
    info!("✅ Database connection established");

    // Create HTTP proxy client
    let http_proxy = HttpProxy::new(Duration::from_secs(config.request_timeout));

    // Create shared state
    let http_state = Arc::new(AppState {
        pool: pool.clone(),
        http_proxy,
    });
    let ws_state = Arc::new(pool);

    // Build router
    let app = Router::new()
        // Health check endpoint
        .route("/health", get(health_check))
        // WebSocket proxy: /ws/{session_id}
        .route("/ws/{session_id}", get(websocket_handler))
        .with_state(ws_state)
        // HTTP/HTTPS proxy: /{session_id}/{*path}
        .route("/{session_id}/{*path}", any(http_proxy_handler))
        .with_state(http_state)
        // Add request tracing
        .layer(TraceLayer::new_for_http());

    // Start server
    let addr = config.bind_address();
    info!("🌐 Server listening on: {}", addr);

    let listener = tokio::net::TcpListener::bind(&addr).await?;
    info!("✅ Server started successfully!");

    axum::serve(listener, app).await?;

    Ok(())
}
