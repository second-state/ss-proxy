use sqlx::{sqlite::SqlitePool, Error as SqlxError};
use tracing::info;

use crate::models::Session;

/// Create database connection pool
pub async fn create_pool(database_url: &str) -> Result<SqlitePool, SqlxError> {
    info!("Connecting to database: {}", database_url);

    let pool = SqlitePool::connect(database_url).await?;

    info!("Database connection pool created successfully");
    Ok(pool)
}

/// Query session information by session_id
pub async fn get_session(pool: &SqlitePool, session_id: &str) -> Result<Session, SqlxError> {
    sqlx::query_as::<_, Session>(
        r#"
        SELECT session_id, downstream_server_url, downstream_server_status
        FROM sessions
        WHERE session_id = ?
        "#,
    )
    .bind(session_id)
    .fetch_one(pool)
    .await
}

/// Insert new session (for testing)
#[allow(dead_code)]
pub async fn insert_session(
    pool: &SqlitePool,
    session_id: &str,
    url: &str,
    status: &str,
) -> Result<(), SqlxError> {
    sqlx::query(
        r#"
        INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
        VALUES (?, ?, ?)
        "#,
    )
    .bind(session_id)
    .bind(url)
    .bind(status)
    .execute(pool)
    .await?;

    Ok(())
}

/// Update session status
#[allow(dead_code)]
pub async fn update_session_status(
    pool: &SqlitePool,
    session_id: &str,
    status: &str,
) -> Result<(), SqlxError> {
    sqlx::query(
        r#"
        UPDATE sessions
        SET downstream_server_status = ?, updated_at = CURRENT_TIMESTAMP
        WHERE session_id = ?
        "#,
    )
    .bind(status)
    .bind(session_id)
    .execute(pool)
    .await?;

    Ok(())
}
