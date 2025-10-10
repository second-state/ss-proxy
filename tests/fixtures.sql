-- Test fixtures for integration tests
-- This file contains test data for HTTP and WebSocket proxy tests

-- Clean up existing test data (if any)
DELETE FROM sessions WHERE session_id LIKE 'test-%';

-- HTTP test sessions (using local Docker services)
-- httpbin service runs on localhost:8888
-- json-api service runs on localhost:8889
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES
  ('test-http', 'http://localhost:8888', 'active'),
  ('test-json', 'http://localhost:8889', 'active');

-- WebSocket test sessions (using local Docker service)
-- ws-echo service runs on localhost:8890
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES
  ('test-ws', 'ws://localhost:8890', 'active');

-- Inactive session for testing error cases
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES
  ('test-inactive', 'http://localhost:8888', 'inactive');
