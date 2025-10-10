#!/usr/bin/env python3
"""
Robust WebSocket Echo Server for Testing

This server echoes back any messages it receives.
It properly handles WebSocket control frames and connection lifecycle.
"""

import asyncio
import logging
import sys

import websockets

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def echo(websocket, path):
    """
    Echo handler that receives messages and sends them back.

    Args:
        websocket: The WebSocket connection
        path: The request path
    """
    client_addr = websocket.remote_address
    logger.info(f"New WebSocket connection from {client_addr} (path: {path})")

    try:
        async for message in websocket:
            # Determine message type
            if isinstance(message, bytes):
                msg_type = "binary"
                msg_size = len(message)
            else:
                msg_type = "text"
                msg_size = len(message)

            # Echo back the message
            await websocket.send(message)
            logger.info(f"Echoed {msg_type} message: {msg_size} bytes from {client_addr}")

    except websockets.exceptions.ConnectionClosedOK:
        logger.info(f"Connection closed normally by {client_addr}")
    except websockets.exceptions.ConnectionClosedError as e:
        logger.warning(f"Connection closed with error from {client_addr}: {e}")
    except Exception as e:
        logger.error(f"Unexpected error in echo handler from {client_addr}: {e}", exc_info=True)
    finally:
        logger.info(f"Connection ended with {client_addr}")


async def main():
    """
    Start the WebSocket echo server.
    """
    host = "0.0.0.0"
    port = 8890

    # Configure server with proper timeouts and settings
    server = await websockets.serve(
        echo,
        host,
        port,
        # Ping settings to keep connection alive
        ping_interval=20,  # Send ping every 20 seconds
        ping_timeout=20,   # Wait 20 seconds for pong response
        close_timeout=10,  # Wait 10 seconds for close handshake
        # Max message size (10MB)
        max_size=10 * 1024 * 1024,
        # Max queue size for incoming messages
        max_queue=32,
    )

    logger.info(f"WebSocket echo server started on {host}:{port}")
    logger.info("Press Ctrl+C to stop")

    # Keep the server running
    try:
        await asyncio.Future()
    except KeyboardInterrupt:
        logger.info("Shutting down server...")
        server.close()
        await server.wait_closed()
        logger.info("Server stopped")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Server interrupted by user")
        sys.exit(0)
        sys.exit(0)
