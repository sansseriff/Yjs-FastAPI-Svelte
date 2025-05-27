import asyncio
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pycrdt_websocket import WebsocketServer, ASGIServer
from fastapi import Request
import uvicorn

from contextlib import asynccontextmanager  # Re-enable for FastAPI lifespan
import os
import sys
from fastapi.responses import HTMLResponse
from pathlib import Path
import mimetypes

mimetypes.init()


if getattr(sys, "frozen", False):
    # inside a PyInstaller bundle
    BASE_DIR = sys._MEIPASS

else:
    # normal Python execution
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))


WEB_DIR = os.path.join(BASE_DIR, "static")

# Global WebsocketServer instance
websocket_server = WebsocketServer()
websocket_server_task = None  # To hold the background task for WebsocketServer


@asynccontextmanager
async def lifespan(app_instance: FastAPI):
    """
    Manages the startup and shutdown of the WebsocketServer using FastAPI's lifespan events.
    """
    global websocket_server_task
    print("Lifespan: Starting WebsocketServer...")
    # Start WebsocketServer in a background task
    # Use asyncio.get_running_loop() in Python 3.7+
    loop = asyncio.get_running_loop()
    websocket_server_task = loop.create_task(websocket_server.start())
    # Wait for it to be fully started
    await websocket_server.started.wait()
    print("Lifespan: WebsocketServer started, yielding to application.")
    try:
        yield  # Application runs here
    finally:
        print("Lifespan: Stopping WebsocketServer...")
        if websocket_server_task:
            if (
                not websocket_server._stopped.is_set()
            ):  # Check if stop() was already called or if it's already stopping
                await websocket_server.stop()  # Signal it to stop
            try:
                # Wait for the websocket_server.start() task to complete
                await asyncio.wait_for(websocket_server_task, timeout=5.0)
                print("Lifespan: WebsocketServer task completed.")
            except asyncio.TimeoutError:
                print(
                    "Lifespan: Timeout waiting for WebsocketServer task to complete. Cancelling."
                )
                websocket_server_task.cancel()
                # Optionally, wait for cancellation to complete
                try:
                    await websocket_server_task
                except asyncio.CancelledError:
                    print("Lifespan: WebsocketServer task was cancelled.")
            except Exception as e:
                print(f"Lifespan: Exception during WebsocketServer task shutdown: {e}")
        else:
            print("Lifespan: WebsocketServer task was not found or already completed.")
    print("Lifespan: WebsocketServer shutdown process finished.")


# Create a main FastAPI application instance with the lifespan manager
app = FastAPI(lifespan=lifespan)

# Create an ASGIServer instance, wrapping the global WebsocketServer.
crdt_asgi_app = ASGIServer(websocket_server)

# Mount the crdt_asgi_app onto the main FastAPI app at the "/ws" path.
app.mount("/ws", crdt_asgi_app)

app.mount("/assets", StaticFiles(directory=Path(WEB_DIR, "assets")), name="assets")


# return the index.html file on browser
@app.get("/", response_class=HTMLResponse)
async def return_index(request: Request):
    mimetypes.add_type("application/javascript", ".js")
    index_path = Path(WEB_DIR, "index.html")
    if not index_path.is_file():
        return HTMLResponse(
            content="<html><body><h1>Error: index.html not found</h1><p>Ensure the Svelte app has been built and output to app/static.</p></body></html>",
            status_code=404,
        )
    return FileResponse(index_path)


# Removed the custom run_uvicorn function as FastAPI's lifespan and uvicorn.run handle this.

if __name__ == "__main__":
    try:
        # Run Uvicorn directly with the app object. Lifespan events will be handled.
        # Ensure the port matches the Svelte client configuration (1234)
        uvicorn.run(app, host="localhost", port=8000, log_level="info")
    except KeyboardInterrupt:
        print("Main: Server shutting down due to KeyboardInterrupt.")
    # Any further cleanup related to asyncio tasks if not handled by lifespan's finally
    # should be considered if issues persist, but lifespan should cover it.
