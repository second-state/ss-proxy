use reqwest::{Client, Method, Request, Url};
use std::time::Duration;
use tracing::{error, info};

/// HTTP proxy client
pub struct HttpProxy {
    client: Client,
}

impl HttpProxy {
    /// Create a new HTTP proxy client
    pub fn new(timeout: Duration) -> Self {
        let client = Client::builder()
            .timeout(timeout)
            .build()
            .expect("Failed to create HTTP client");

        Self { client }
    }

    /// Forward HTTP request to downstream server
    pub async fn forward_request(
        &self,
        downstream_url: &str,
        path: &str,
        method: Method,
        headers: axum::http::HeaderMap,
        body: axum::body::Bytes,
    ) -> Result<axum::response::Response, ProxyError> {
        // Construct full downstream URL
        let full_url = format!("{}{}", downstream_url.trim_end_matches('/'), path);
        info!("Forwarding request to: {} {}", method, full_url);

        let url = Url::parse(&full_url).map_err(|e| {
            error!("Invalid URL: {} - {}", full_url, e);
            ProxyError::InvalidUrl(full_url.clone())
        })?;

        // Build request
        let mut request = Request::new(method.clone(), url);

        // Copy request headers (filter out headers that shouldn't be forwarded)
        let request_headers = request.headers_mut();
        for (key, value) in headers.iter() {
            let key_str = key.as_str();
            // Skip headers that shouldn't be forwarded
            if !matches!(
                key_str,
                "host" | "connection" | "transfer-encoding" | "content-length"
            ) && let Ok(name) = reqwest::header::HeaderName::from_bytes(key.as_str().as_bytes())
                && let Ok(val) = reqwest::header::HeaderValue::from_bytes(value.as_bytes())
            {
                request_headers.insert(name, val);
            }
        }

        // Set request body
        if !body.is_empty() {
            *request.body_mut() = Some(body.to_vec().into());
        }

        // Send request
        let response = self.client.execute(request).await.map_err(|e| {
            error!("Failed to request downstream server: {}", e);
            ProxyError::RequestFailed(e.to_string())
        })?;

        info!(
            "Received response from downstream server: {}",
            response.status()
        );

        // Build response
        let mut builder = axum::http::Response::builder().status(response.status());

        // Copy response headers
        for (key, value) in response.headers().iter() {
            builder = builder.header(key, value);
        }

        // Get response body
        let body_bytes = response.bytes().await.map_err(|e| {
            error!("Failed to read response body: {}", e);
            ProxyError::ResponseReadFailed(e.to_string())
        })?;

        // Build final response
        let final_response = builder
            .body(axum::body::Body::from(body_bytes))
            .map_err(|e| {
                error!("Failed to build response: {}", e);
                ProxyError::ResponseBuildFailed(e.to_string())
            })?;

        Ok(final_response)
    }
}

/// Proxy error types
#[derive(Debug, thiserror::Error)]
pub enum ProxyError {
    #[error("Invalid URL: {0}")]
    InvalidUrl(String),

    #[error("Request failed: {0}")]
    RequestFailed(String),

    #[error("Failed to read response: {0}")]
    ResponseReadFailed(String),

    #[error("Failed to build response: {0}")]
    ResponseBuildFailed(String),
}
