# Svelte + FastAPI + PyCRDT Websocket

A collaborative web application that demonstrates real-time synchronization between clients using Conflict-free Replicated Data Types (CRDTs).

## Tech Stack

- **Frontend**: Svelte with Yjs for CRDT implementation
- **Backend**: FastAPI with PyCRDT-Websocket for WebSocket communication
- **Synchronization**: Real-time data synchronization using the CRDT protocol

## Features

- Real-time collaborative text editing
- Awareness of other connected users
- Works offline and handles synchronization when reconnecting

## Getting Started

### Prerequisites

- Python 3.8+ (preferably 3.13)
- Node.js or Bun

### Setup

Run the setup script to install all dependencies:

```bash
chmod +x dev-setup.sh
./dev-setup.sh
```

This script will:

1. Set up a Python virtual environment with required dependencies
2. Initialize and build the Svelte frontend
3. Configure the connection between frontend and backend

### Running the Application

For the best experience, follow these steps:

1. Build the frontend:

```bash
cd web
bun run build
```

2. Run the backend server:

```bash
cd ../app
uv run fastapi dev main.py
```

3. Open your browser at http://localhost:8000

## License

MIT
