use serde::{Deserialize, Serialize};
use sqlx::FromRow;

/// Session information, corresponds to the sessions table in the database
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Session {
    /// Session ID
    pub session_id: String,
    /// Downstream server URL
    pub downstream_server_url: String,
    /// Downstream server status
    pub downstream_server_status: String,
}

impl Session {
    /// Check if the downstream server is available
    pub fn is_available(&self) -> bool {
        matches!(
            self.downstream_server_status.as_str(),
            "active" | "online" | "ready"
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_available() {
        let session = Session {
            session_id: "test".to_string(),
            downstream_server_url: "http://localhost:8080".to_string(),
            downstream_server_status: "active".to_string(),
        };
        assert!(session.is_available());

        let inactive = Session {
            session_id: "test".to_string(),
            downstream_server_url: "http://localhost:8080".to_string(),
            downstream_server_status: "inactive".to_string(),
        };
        assert!(!inactive.is_available());
    }
}
