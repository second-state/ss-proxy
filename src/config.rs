use std::path::PathBuf;

use crate::CliArgs;

#[derive(Debug, Clone)]
pub struct Config {
    /// Proxy server listening address
    pub host: String,
    /// Proxy server listening port
    pub port: u16,
    /// Database file path
    pub db_path: String,
    /// Request timeout in seconds
    pub request_timeout: u64,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            host: "0.0.0.0".to_string(),
            port: 8080,
            db_path: "./sessions.db".to_string(),
            request_timeout: 30,
        }
    }
}

#[allow(dead_code)]
impl Config {
    /// Create a new configuration
    pub fn new() -> Self {
        Self::default()
    }

    /// Set listening address
    pub fn with_host(mut self, host: impl Into<String>) -> Self {
        self.host = host.into();
        self
    }

    /// Set listening port
    pub fn with_port(mut self, port: u16) -> Self {
        self.port = port;
        self
    }

    /// Set database path (supports relative and absolute paths)
    pub fn with_db_path(mut self, path: impl Into<String>) -> Self {
        self.db_path = path.into();
        self
    }

    /// Set request timeout
    pub fn with_timeout(mut self, timeout: u64) -> Self {
        self.request_timeout = timeout;
        self
    }

    /// Get database connection string
    /// Automatically handles relative and absolute paths
    pub fn database_url(&self) -> String {
        let path = PathBuf::from(&self.db_path);

        if path.is_absolute() {
            // Absolute path: sqlite:///absolute/path/to/db.db
            format!("sqlite://{}", path.display())
        } else {
            // Relative path: sqlite:./relative/path/to/db.db
            format!("sqlite:{}", self.db_path)
        }
    }

    /// Get server bind address
    pub fn bind_address(&self) -> String {
        format!("{}:{}", self.host, self.port)
    }
}

impl From<CliArgs> for Config {
    fn from(args: CliArgs) -> Self {
        Self {
            host: args.host,
            port: args.port,
            db_path: args.db_path,
            request_timeout: args.timeout,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_relative_path() {
        let config = Config::new().with_db_path("./sessions.db");
        assert_eq!(config.database_url(), "sqlite:./sessions.db");
    }

    #[test]
    fn test_absolute_path() {
        let config = Config::new().with_db_path("/tmp/sessions.db");
        assert_eq!(config.database_url(), "sqlite:///tmp/sessions.db");
    }

    #[test]
    fn test_bind_address() {
        let config = Config::new();
        assert_eq!(config.bind_address(), "0.0.0.0:8080");
    }
}
