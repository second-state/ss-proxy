#!/usr/bin/env python3
"""
Ultra-Robust WebSocket Echo Server for Testing

This server echoes back any messages it receives using a manual receive loop
instead of async for, which can exit unexpectedly in some scenarios.
"""

import asyncio
import logging
import sys

import websockets

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)


async def echo(websocket, path):
    """
    Echo handler that receives messages and sends them back using manual loop.

    Args:
        websocket: The WebSocket connection
        path: The request path
    """
    client_addr = websocket.remote_address
    logger.info(f"✅ New connection from {client_addr} to {path}")

    message_count = 0
    try:
        # Manual receive loop with explicit error checking
        while True:
            try:
                # Wait for message with timeout
                message = await asyncio.wait_for(
                    websocket.recv(), timeout=60.0  # 60 second timeout
                )

                message_count += 1
                msg_type = "binary" if isinstance(message, bytes) else "text"
                msg_size = len(message)

                logger.info(
                    f"📨 Received {msg_type} message #{message_count}: {msg_size} bytes from {client_addr}"
                )

                # Echo back immediately
                await websocket.send(message)
                logger.info(
                    f"📤 Echoed {msg_type} message #{message_count}: {msg_size} bytes to {client_addr}"
                )

            except asyncio.TimeoutError:
                logger.warning(f"⏰ Timeout waiting for message from {client_addr}")
                continue
            except websockets.exceptions.ConnectionClosedOK:
                logger.info(
                    f"✅ Connection closed normally by {client_addr} after {message_count} messages"
                )
                break
            except websockets.exceptions.ConnectionClosedError as e:
                logger.warning(
                    f"⚠️  Connection closed with error from {client_addr}: {e}"
                )
                break

    except Exception as e:
        logger.error(f"❌ Unexpected error handling {client_addr}: {e}", exc_info=True)
    finally:
        logger.info(
            f"🔚 Handler ended for {client_addr} (processed {message_count} messages)"
        )


async def main():
    """
    Start the WebSocket echo server.
    """
    host = "0.0.0.0"
    port = 8890

    logger.info(f"🚀 Starting WebSocket echo server on {host}:{port}")

    # Start server with very permissive settings
    server = await websockets.serve(
        echo,
        host,
        port,
        ping_interval=None,  # Disable ping/pong (let client handle it)
        ping_timeout=None,  # No ping timeout
        close_timeout=10,  # 10 seconds for close handshake
        max_size=10 * 1024 * 1024,  # 10MB max message
        max_queue=32,  # Max 32 queued messages
        compression=None,  # Disable compression for simplicity
    )

    logger.info(f"✅ WebSocket echo server is ready and listening")

    # Keep the server running
    try:
        await asyncio.Future()
    except KeyboardInterrupt:
        logger.info("🛑 Shutting down server...")
        server.close()
        await server.wait_closed()
        logger.info("✅ Server stopped")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("🛑 Server interrupted by user")
        sys.exit(0)
