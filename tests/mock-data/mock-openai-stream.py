#!/usr/bin/env python3
"""
Mock OpenAI-style Streaming Server
Simulates a streaming LLM API endpoint for testing ss-proxy streaming capabilities
"""

import json
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer


class StreamingHandler(BaseHTTPRequestHandler):
    """Handler for streaming responses"""

    def do_POST(self):
        """Handle POST requests to /v1/chat/completions"""
        if self.path == '/v1/chat/completions':
            self.handle_chat_completions()
        else:
            self.send_error(404, "Not Found")

    def handle_chat_completions(self):
        """Simulate OpenAI-style streaming response"""
        # Read request body
        content_length = int(self.headers['Content-Length'])
        body = self.rfile.read(content_length)

        try:
            request_data = json.loads(body)
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
            return

        # Check if streaming is requested
        stream = request_data.get('stream', False)

        if stream:
            self.send_streaming_response(request_data)
        else:
            self.send_complete_response(request_data)

    def send_streaming_response(self, request_data):
        """Send SSE-style streaming response"""
        # Send headers
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('Connection', 'keep-alive')
        self.end_headers()

        # Simulate streaming chunks
        message = "Hello! This is a streaming response from the mock server. "
        message += "It simulates how OpenAI's API sends data in chunks. "
        message += "Each word is sent as a separate event."

        words = message.split()

        for i, word in enumerate(words):
            chunk = {
                "id": "chatcmpl-123",
                "object": "chat.completion.chunk",
                "created": int(time.time()),
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "delta": {
                        "content": word + " "
                    },
                    "finish_reason": None
                }]
            }

            # Send SSE format
            data = f"data: {json.dumps(chunk)}\n\n"
            self.wfile.write(data.encode('utf-8'))
            self.wfile.flush()

            # Simulate processing delay
            time.sleep(0.1)

        # Send final chunk
        final_chunk = {
            "id": "chatcmpl-123",
            "object": "chat.completion.chunk",
            "created": int(time.time()),
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "delta": {},
                "finish_reason": "stop"
            }]
        }

        data = f"data: {json.dumps(final_chunk)}\n\n"
        self.wfile.write(data.encode('utf-8'))
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()

    def send_complete_response(self, request_data):
        """Send complete (non-streaming) response"""
        response = {
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": int(time.time()),
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "Hello! This is a complete response from the mock server."
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 12,
                "total_tokens": 22
            }
        }

        # Send response
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response).encode('utf-8'))

    def log_message(self, format, *args):
        """Custom log format"""
        sys.stderr.write(f"[{self.log_date_time_string()}] {format % args}\n")

def run_server(port=10086):
    """Start the mock server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, StreamingHandler)
    print(f"🚀 Mock OpenAI streaming server running on http://localhost:{port}")
    print(f"📡 Endpoint: http://localhost:{port}/v1/chat/completions")
    print(f"💡 Test with: curl -X POST http://localhost:{port}/v1/chat/completions \\")
    print(f"              -H 'Content-Type: application/json' \\")
    print(f"              -d '{{\"stream\": true, \"messages\": [{{\"role\": \"user\", \"content\": \"Hello\"}}]}}'")
    print(f"\n🛑 Press Ctrl+C to stop\n")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n\n👋 Shutting down server...")
        httpd.shutdown()

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 10086
    run_server(port)
