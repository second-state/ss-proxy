// Integration tests for ss-proxy server
// Tests HTTP/HTTPS and WebSocket proxy functionality

use std::process::{Child, Command};
use std::sync::{Mutex, Once};
use tokio::time::Duration;

static INIT: Once = Once::new();
static SERVER_PROCESS: Mutex<Option<Child>> = Mutex::new(None);

/// Get test server port from environment variable or use default 8080
fn get_test_port() -> u16 {
    std::env::var("TEST_PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8080)
}

/// Get base URL for HTTP tests
fn get_base_url() -> String {
    format!("http://localhost:{}", get_test_port())
}

/// Get WebSocket base URL for WS tests
fn get_ws_base_url() -> String {
    format!("ws://localhost:{}", get_test_port())
}

/// Cleanup function to kill the test server
fn cleanup_test_server() {
    println!("🧹 Cleaning up test server...");
    if let Ok(mut guard) = SERVER_PROCESS.lock() {
        if let Some(mut child) = guard.take() {
            let pid = child.id();
            println!("🛑 Killing server process (PID: {})", pid);

            // On Unix, kill the entire process group
            #[cfg(unix)]
            {
                use std::process::Command as SysCommand;
                // Try to kill the process group first
                let _ = SysCommand::new("kill")
                    .args(&["-TERM", &format!("-{}", pid)])
                    .status();
                std::thread::sleep(std::time::Duration::from_millis(500));
            }

            // Then kill the process itself
            let _ = child.kill();
            let _ = child.wait();
            println!("✅ Server process stopped");
        }
    }
}

/// Initialize test environment (start server, wait for it to be ready)
fn setup_test_server() {
    INIT.call_once(|| {
        println!("🚀 Setting up test environment...");

        // Initialize database with test data
        let init_status = Command::new("sh")
            .arg("-c")
            .arg("./init_db.sh && sqlite3 sessions.db < tests/fixtures.sql")
            .status()
            .expect("Failed to initialize database");

        assert!(init_status.success(), "Database initialization failed");

        // Build the project in release mode
        let build_status = Command::new("cargo")
            .args(&["build", "--release"])
            .status()
            .expect("Failed to build project");

        assert!(build_status.success(), "Build failed");

        // Start the server in background
        let port = get_test_port();
        println!("🔧 Starting server on port {}", port);

        // Build server command with environment variables
        // Use a process group so we can kill all children later
        let mut server_cmd = Command::new("./target/release/ss-proxy");
        server_cmd
            .args(&["--port", &port.to_string(), "--log-level", "debug"])
            .env("TEST_PORT", port.to_string()); // Ensure child process knows the port

        // On Unix, set process group ID to enable killing the entire group
        #[cfg(unix)]
        {
            use std::os::unix::process::CommandExt;
            server_cmd.process_group(0);
        }

        let server = server_cmd.spawn().expect("Failed to start server");

        *SERVER_PROCESS.lock().unwrap() = Some(server);

        // Wait for server to start
        println!("⏳ Waiting for server to start...");
        std::thread::sleep(std::time::Duration::from_secs(3));
        println!("✅ Server started on port {}", port);
    });
}

/// Cleanup function to kill the server when all tests are done
pub struct TestCleanup;

impl Drop for TestCleanup {
    fn drop(&mut self) {
        // This will be called when CLEANUP_GUARD is dropped
        // In practice, this may not be called by the test runner
        // Use cleanup_test_server() explicitly or run ./cleanup_test_server.sh
        cleanup_test_server();
    }
}

// Global cleanup guard - attempt to cleanup when binary exits
// NOTE: Rust's test runner may not call this reliably
// If tests leave the server running, manually run: ./cleanup_test_server.sh <PORT>
#[allow(dead_code)]
static CLEANUP_GUARD: TestCleanup = TestCleanup;

// Alternative: implement a custom test macro or add cleanup to each test
// For now, users should run cleanup_test_server.sh after tests if needed

struct ServerGuard;

impl Drop for ServerGuard {
    fn drop(&mut self) {
        // Don't kill the server on each test - it should persist across all tests
        // Cleanup will happen via the global CLEANUP_GUARD when all tests finish
    }
}

// =============================================================================
// HTTP/HTTPS Proxy Tests
// =============================================================================

#[tokio::test]
async fn test_health_check() {
    setup_test_server();
    let _guard = ServerGuard;

    let client = reqwest::Client::new();
    let response = client
        .get(format!("{}/health", get_base_url()))
        .send()
        .await
        .expect("Failed to send request");

    assert_eq!(response.status(), 200);
    let body = response.text().await.expect("Failed to read response");
    assert_eq!(body, "OK");
}

#[tokio::test]
async fn test_http_proxy_get() {
    setup_test_server();
    let _guard = ServerGuard;

    let client = reqwest::Client::new();
    let response = client
        .get(format!("{}/test-http/get", get_base_url()))
        .send()
        .await
        .expect("Failed to send request");

    assert_eq!(response.status(), 200);

    let json: serde_json::Value = response.json().await.expect("Failed to parse JSON");
    assert_eq!(json["url"], "http://localhost:8888/get");
}

#[tokio::test]
async fn test_http_proxy_post() {
    setup_test_server();
    let _guard = ServerGuard;

    let client = reqwest::Client::new();
    let payload = serde_json::json!({
        "test": "data",
        "number": 42
    });

    let response = client
        .post(format!("{}/test-http/post", get_base_url()))
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
    setup_test_server();
    let _guard = ServerGuard;

    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(60)) // Increase timeout to 60 seconds
        .build()
        .expect("Failed to build client");

    let response = client
        .get(format!(
            "{}/test-http/get?foo=bar&hello=world",
            get_base_url()
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
    setup_test_server();
    let _guard = ServerGuard;

    let client = reqwest::Client::new();
    let response = client
        .get(format!("{}/test-http/headers", get_base_url()))
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
    setup_test_server();
    let _guard = ServerGuard;

    let client = reqwest::Client::new();
    let response = client
        .get(format!("{}/nonexistent-session/get", get_base_url()))
        .send()
        .await
        .expect("Failed to send request");

    assert_eq!(response.status(), 404);
}

#[tokio::test]
async fn test_inactive_session() {
    setup_test_server();
    let _guard = ServerGuard;

    let client = reqwest::Client::new();
    let response = client
        .get(format!("{}/test-inactive/get", get_base_url()))
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

    setup_test_server();
    let _guard = ServerGuard;

    // Connect to WebSocket proxy
    let (ws_stream, _) = connect_async(format!("{}/ws/test-ws", get_ws_base_url()))
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

    setup_test_server();
    let _guard = ServerGuard;

    let (ws_stream, _) = connect_async(format!("{}/ws/test-ws", get_ws_base_url()))
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

    setup_test_server();
    let _guard = ServerGuard;

    // Try to connect to non-existent session
    let result = connect_async(format!("{}/ws/nonexistent-session", get_ws_base_url())).await;

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

    setup_test_server();
    let _guard = ServerGuard;

    let (ws_stream, _) = connect_async(format!("{}/ws/test-ws", get_ws_base_url()))
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

// =============================================================================
// Cleanup Test - Runs last to kill the server
// =============================================================================

/// This test should ideally run last to clean up the server
/// Note: Test execution order is not guaranteed in Rust
/// If server is still running after tests, use: ./cleanup_test_server.sh <PORT>
#[tokio::test]
async fn test_zzz_cleanup() {
    // Use zzz_ prefix to encourage this test to run last (though not guaranteed)
    println!("🧹 Running cleanup test...");
    cleanup_test_server();
    println!("✅ Cleanup test complete");
}
