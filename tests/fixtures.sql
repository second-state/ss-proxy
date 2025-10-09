-- Test fixtures for integration tests
-- This file contains test data for HTTP and WebSocket proxy tests

-- Clean up existing test data (if any)
DELETE FROM sessions WHERE session_id LIKE 'test-%';

-- HTTP test sessions
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES
  ('test-http', 'https://httpbin.org', 'active'),
  ('test-json', 'https://jsonplaceholder.typicode.com', 'active');

-- WebSocket test sessions
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES
  ('test-ws', 'wss://echo.websocket.org', 'active');

-- Inactive session for testing error cases
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES
  ('test-inactive', 'https://httpbin.org', 'inactive');
