// Integration tests for ss-proxy server
// Tests HTTP/HTTPS and WebSocket proxy functionality
// Each test has its own isolated server instance

use std::process::{Child, Command};
use std::sync::atomic::{AtomicU16, Ordering};
use tokio::time::Duration;

// Global port allocator to avoid conflicts between tests
static NEXT_PORT: AtomicU16 = AtomicU16::new(8080);

/// Allocate a unique port for each test
fn allocate_test_port() -> u16 {
    NEXT_PORT.fetch_add(1, Ordering::SeqCst)
}

/// Test server instance - automatically cleaned up when dropped
struct TestServer {
    process: Child,
    port: u16,
    db_path: String,
}

impl TestServer {
    /// Start a new test server on a unique port
    async fn start() -> Self {
        let port = allocate_test_port();
        let db_path = format!("./test_sessions_{}.db", port);

        println!("🚀 Starting isolated test server on port {} with database {}", port, db_path);

        // Initialize database with test data
        let init_cmd = format!("./init_db.sh {} && sqlite3 {} < tests/fixtures.sql", db_path, db_path);
        let init_status = Command::new("sh")
            .arg("-c")
            .arg(&init_cmd)
            .status()
            .expect("Failed to initialize database");

        assert!(init_status.success(), "Database initialization failed");

        // Build the project in release mode (if not already built)
        static BUILD_ONCE: std::sync::Once = std::sync::Once::new();
        BUILD_ONCE.call_once(|| {
            println!("🔨 Building project...");
            let build_status = Command::new("cargo")
                .args(&["build", "--release"])
                .status()
                .expect("Failed to build project");
            assert!(build_status.success(), "Build failed");
            println!("✅ Build complete");
        });

        // Start the server in background with isolated database
        let mut server_cmd = Command::new("./target/release/ss-proxy");
        server_cmd
            .args(&[
                "--port", &port.to_string(),
                "--db-path", &db_path,
                "--log-level", "debug"
            ])
            .env("TEST_PORT", port.to_string());

        // On Unix, set process group ID to enable killing the entire group
        #[cfg(unix)]
        {
            use std::os::unix::process::CommandExt;
            server_cmd.process_group(0);
        }

        let process = server_cmd.spawn().expect("Failed to start server");
        let pid = process.id();

        println!("⏳ Waiting for server (PID: {}) to be ready...", pid);

        // Wait for server to be ready (with health check)
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(1))
            .build()
            .unwrap();

        for i in 0..30 {
            tokio::time::sleep(Duration::from_millis(200)).await;

            if let Ok(response) = client
                .get(format!("http://localhost:{}/health", port))
                .send()
                .await
            {
                if response.status().is_success() {
                    println!("✅ Server ready on port {} (took {}ms)", port, i * 200);
                    return TestServer { process, port, db_path };
                }
            }
        }

        panic!("Server failed to start within 6 seconds on port {}", port);
    }

    /// Get the base URL for HTTP tests
    fn base_url(&self) -> String {
        format!("http://localhost:{}", self.port)
    }

    /// Get the WebSocket base URL
    fn ws_base_url(&self) -> String {
        format!("ws://localhost:{}", self.port)
    }
}

impl Drop for TestServer {
    fn drop(&mut self) {
        let pid = self.process.id();
        println!("🛑 Stopping test server (PID: {}) on port {}", pid, self.port);

        // On Unix, kill the entire process group
        #[cfg(unix)]
        {
            use std::process::Command as SysCommand;
            let _ = SysCommand::new("kill")
                .args(&["-TERM", &format!("-{}", pid)])
                .status();
            std::thread::sleep(std::time::Duration::from_millis(300));
        }

        // Then kill the process itself
        let _ = self.process.kill();
        let _ = self.process.wait();

        println!("✅ Server stopped on port {}", self.port);

        // Clean up test database
        if std::path::Path::new(&self.db_path).exists() {
            let _ = std::fs::remove_file(&self.db_path);
            println!("🗑️  Removed test database: {}", self.db_path);
        }

        // Small delay to ensure port is released
        std::thread::sleep(std::time::Duration::from_millis(100));
    }
}

// =============================================================================
// HTTP/HTTPS Proxy Tests
// =============================================================================

#[tokio::test]
async fn test_health_check() {
    let server = TestServer::start().await;


    let client = reqwest::Client::new();
    let response = client
        .get(format!("{}/health", server.base_url()))
        .send()
        .await
        .expect("Failed to send request");

    assert_eq!(response.status(), 200);
    let body = response.text().await.expect("Failed to read response");
    assert_eq!(body, "OK");
}

#[tokio::test]
async fn test_http_proxy_get() {
    let server = TestServer::start().await;

    let client = reqwest::Client::new();
    let response = client
        .get(format!("{}/test-http/get", server.base_url()))
        .send()
        .await
        .expect("Failed to send request");

    assert_eq!(response.status(), 200);

    let json: serde_json::Value = response.json().await.expect("Failed to parse JSON");
    assert_eq!(json["url"], "http://localhost:8888/get");
}

#[tokio::test]
async fn test_http_proxy_post() {
    let server = TestServer::start().await;

    let client = reqwest::Client::new();
    let payload = serde_json::json!({
        "test": "data",
        "number": 42
    });

    let response = client
        .post(format!("{}/test-http/post", server.base_url()))
        .json(&payload)
        .send()
        .await
        .expect("Failed to send request");

    assert_eq!(response.status(), 200);

    let json: serde_json::Value = response.json().await.expect("Failed to parse JSON");
    assert_eq!(json["json"]["test"], "data");
    assert_eq!(json["json"]["number"], 42);
}

#[tokio::test]
async fn test_http_proxy_with_query_params() {
    let server = TestServer::start().await;

    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(60))
        .build()
        .expect("Failed to build client");

    let response = client
        .get(format!(
            "{}/test-http/get?foo=bar&hello=world",
            server.base_url()
        ))
        .send()
        .await
        .expect("Failed to send request");

    assert_eq!(response.status(), 200);

    let json: serde_json::Value = response.json().await.expect("Failed to parse JSON");
    assert_eq!(json["args"]["foo"], "bar");
    assert_eq!(json["args"]["hello"], "world");
}

#[tokio::test]
async fn test_http_proxy_custom_headers() {
    let server = TestServer::start().await;

    let client = reqwest::Client::new();
    let response = client
        .get(format!("{}/test-http/headers", server.base_url()))
        .header("X-Custom-Header", "test-value")
        .send()
        .await
        .expect("Failed to send request");

    assert_eq!(response.status(), 200);

    let json: serde_json::Value = response.json().await.expect("Failed to parse JSON");
    assert_eq!(json["headers"]["X-Custom-Header"], "test-value");
}

#[tokio::test]
async fn test_session_not_found() {
    let server = TestServer::start().await;

    let client = reqwest::Client::new();
    let response = client
        .get(format!("{}/nonexistent-session/get", server.base_url()))
        .send()
        .await
        .expect("Failed to send request");

    assert_eq!(response.status(), 404);
}

#[tokio::test]
async fn test_inactive_session() {
    let server = TestServer::start().await;

    let client = reqwest::Client::new();
    let response = client
        .get(format!("{}/test-inactive/get", server.base_url()))
        .send()
        .await
        .expect("Failed to send request");

    assert_eq!(response.status(), 503);
}

// =============================================================================
// WebSocket Proxy Tests
// =============================================================================

#[tokio::test]
async fn test_websocket_echo() {
    use futures_util::{SinkExt, StreamExt};
    use tokio_tungstenite::connect_async;
    use tokio_tungstenite::tungstenite::Message;

    let server = TestServer::start().await;

    // Connect to WebSocket proxy
    let (ws_stream, _) = connect_async(format!("{}/ws/test-ws", server.ws_base_url()))
        .await
        .expect("Failed to connect to WebSocket");

    let (mut write, mut read) = ws_stream.split();

    // Send a text message
    let test_message = "Hello WebSocket!";
    write
        .send(Message::Text(test_message.to_string().into()))
        .await
        .expect("Failed to send message");

    // Receive the echo
    let received = tokio::time::timeout(Duration::from_secs(5), read.next())
        .await
        .expect("Timeout waiting for message")
        .expect("No message received")
        .expect("Error receiving message");

    match received {
        Message::Text(text) => {
            let text_str = text.to_string();
            assert_eq!(text_str, test_message);
        }
        _ => panic!("Expected text message, got: {:?}", received),
    }
}

#[tokio::test]
async fn test_websocket_binary_message() {
    use futures_util::{SinkExt, StreamExt};
    use tokio_tungstenite::connect_async;
    use tokio_tungstenite::tungstenite::Message;

    let server = TestServer::start().await;

    let (ws_stream, _) = connect_async(format!("{}/ws/test-ws", server.ws_base_url()))
        .await
        .expect("Failed to connect to WebSocket");

    let (mut write, mut read) = ws_stream.split();

    // Send binary data
    let test_data = vec![1u8, 2, 3, 4, 5];
    write
        .send(Message::Binary(test_data.clone().into()))
        .await
        .expect("Failed to send binary message");

    // Receive the echo
    let received = tokio::time::timeout(Duration::from_secs(5), read.next())
        .await
        .expect("Timeout waiting for message")
        .expect("No message received")
        .expect("Error receiving message");

    match received {
        Message::Binary(data) => {
            assert_eq!(data.to_vec(), test_data);
        }
        _ => panic!("Expected binary message, got: {:?}", received),
    }
}

#[tokio::test]
async fn test_websocket_session_not_found() {
    use tokio_tungstenite::connect_async;

    let server = TestServer::start().await;

    // Try to connect to non-existent session
    let result = connect_async(format!("{}/ws/nonexistent-session", server.ws_base_url())).await;

    assert!(
        result.is_err(),
        "Connection should fail for non-existent session"
    );
}

#[tokio::test]
async fn test_websocket_multiple_messages() {
    use futures_util::{SinkExt, StreamExt};
    use tokio_tungstenite::connect_async;
    use tokio_tungstenite::tungstenite::Message;

    let server = TestServer::start().await;

    let (ws_stream, _) = connect_async(format!("{}/ws/test-ws", server.ws_base_url()))
        .await
        .expect("Failed to connect to WebSocket");

    let (mut write, mut read) = ws_stream.split();

    // Send multiple messages
    let messages = vec!["Message 1", "Message 2", "Message 3"];

    for msg in &messages {
        write
            .send(Message::Text(msg.to_string().into()))
            .await
            .expect("Failed to send message");

        // Receive the echo
        let received = tokio::time::timeout(Duration::from_secs(5), read.next())
            .await
            .expect("Timeout waiting for message")
            .expect("No message received")
            .expect("Error receiving message");

        match received {
            Message::Text(text) => {
                let text_str = text.to_string();
                assert_eq!(&text_str, msg);
            }
            _ => panic!("Expected text message"),
        }
    }
}
