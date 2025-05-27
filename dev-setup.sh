#!/usr/bin/env bash

# Dev setup script for svelte-fastapi-pycrdt-websocket project
# This script helps set up the development environment for both Python backend and Svelte frontend

set -e  # Exit on error

# Color codes for better readability
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Project directories
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKEND_DIR="$PROJECT_DIR/app"
FRONTEND_DIR="$PROJECT_DIR/web"

# Print section header
section() {
  echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Print success message
success() {
  echo -e "${GREEN}✓ $1${NC}"
}

# Print warning message
warn() {
  echo -e "${YELLOW}! $1${NC}"
}

# Print error message
error() {
  echo -e "${RED}✗ $1${NC}"
}

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Ask for confirmation (y/n)
confirm() {
  read -p "$1 (y/n) " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]]
}

# Check Python version
check_python() {
  section "Checking Python"
  
  if command_exists python; then
    PYTHON_CMD="python"
  elif command_exists python3; then
    PYTHON_CMD="python3"
  else
    error "Python not found. Please install Python 3.8+ before proceeding."
    exit 1
  fi
  
  PYTHON_VERSION=$($PYTHON_CMD --version | cut -d " " -f 2)
  echo "Python version: $PYTHON_VERSION"
  
  # Extract the major and minor version
  PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
  PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
  
  if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]); then
    warn "This project recommends Python 3.8 or newer."
    if ! confirm "Continue anyway?"; then
      exit 1
    fi
  else
    success "Python version looks good!"
  fi
}

# Install uv package manager
setup_uv() {
  section "Python Environment Setup"
  
  if command_exists uv; then
    success "uv is already installed."
  else
    echo "uv package manager not found."
    if confirm "Would you like to install uv?"; then
      echo "Installing uv..."
      curl -fsSL https://astral.sh/uv/install.sh | bash
      export PATH="$HOME/.cargo/bin:$PATH"  # Add to path for this session
      success "uv installed successfully!"
    else
      warn "Skipping uv installation. You'll need to set up your Python environment manually."
    fi
  fi
  
  if command_exists uv; then
    # Create venv and install dependencies
    echo "Setting up Python virtual environment..."
    cd "$BACKEND_DIR"
    uv venv
    source .venv/bin/activate
    uv pip install -e .
    success "Python environment set up successfully!"
  else
    warn "Skipping Python environment setup. You'll need to set it up manually."
  fi
}

# Install Bun for Svelte development
setup_bun() {
  section "Node.js/Bun Setup for Svelte"
  
  if command_exists bun; then
    success "bun is already installed."
    BUN_VERSION=$(bun --version)
    echo "Bun version: $BUN_VERSION"
  else
    echo "bun package manager not found."
    if confirm "Would you like to install bun?"; then
      echo "Installing bun..."
      curl -fsSL https://bun.sh/install | bash
      # Use the updated PATH for this session
      export PATH="$HOME/.bun/bin:$PATH"
      success "bun installed successfully!"
    else
      warn "Skipping bun installation. You'll need Node.js/npm to set up Svelte manually."
    fi
  fi
}

# Set up Svelte frontend
setup_svelte() {
  section "Svelte Frontend Setup"
  
  # Initialize Svelte project if it's empty
  if [ ! -f "$FRONTEND_DIR/package.json" ]; then
    echo "Initializing Svelte project..."
    
    # Check for dependencies
    local js_pkg_manager=""
    
    if command_exists bun; then
      js_pkg_manager="bun"
    elif command_exists npm; then
      js_pkg_manager="npm"
    elif command_exists yarn; then
      js_pkg_manager="yarn"
    elif command_exists pnpm; then
      js_pkg_manager="pnpm"
    else
      error "No JavaScript package manager found. Please install bun, npm, yarn, or pnpm."
      return 1
    fi
    
    echo "Using $js_pkg_manager to set up Svelte project..."
    cd "$FRONTEND_DIR"
    
    if [[ "$js_pkg_manager" == "bun" ]]; then
      bun create svelte@latest .
    else
      # Fallback for npm/yarn/pnpm
      $js_pkg_manager create svelte@latest .
    fi
    
    # Install dependencies
    echo "Installing Svelte dependencies..."
    if [[ "$js_pkg_manager" == "bun" ]]; then
      bun install
      bun add y-websocket yjs
    else
      $js_pkg_manager install
      $js_pkg_manager add y-websocket yjs
    fi
    
    success "Svelte project initialized and dependencies installed!"
  else
    echo "Svelte project already initialized."
    
    # Just install dependencies if package.json exists but node_modules doesn't
    if [ ! -d "$FRONTEND_DIR/node_modules" ]; then
      echo "Installing Svelte dependencies..."
      cd "$FRONTEND_DIR"
      
      if command_exists bun; then
        bun install
      elif command_exists npm; then
        npm install
      elif command_exists yarn; then
        yarn
      elif command_exists pnpm; then
        pnpm install
      else
        warn "No package manager found. Please install dependencies manually."
      fi
    fi
  fi
}

# Build the Svelte project and copy to static folder
build_frontend() {
  section "Building Svelte Frontend"
  
  cd "$FRONTEND_DIR"
  
  if command_exists bun; then
    bun run build
  elif command_exists npm; then
    npm run build
  elif command_exists yarn; then
    yarn build
  elif command_exists pnpm; then
    pnpm build
  else
    error "No package manager found. Cannot build frontend."
    return 1
  fi
  
  # Ensure static directory exists
  mkdir -p "$BACKEND_DIR/static"
  
  # Copy built files to static folder
  echo "Copying built files to backend static directory..."
  cp -r "$FRONTEND_DIR/dist/"* "$BACKEND_DIR/static/"
  
  success "Frontend built and copied to backend static directory!"
}

# Show instructions for running the project
show_instructions() {
  section "Next Steps"
  
  echo -e "${GREEN}Setup completed successfully!${NC}"
  echo
  echo "To run the backend server:"
  echo -e "  ${BLUE}cd $BACKEND_DIR${NC}"
  echo -e "  ${BLUE}uv run fastapi dev main.py${NC}  # For development with auto-reload (no need to activate venv)"
  echo -e "  ${BLUE}# or python main.py${NC}  # For standard execution (requires activated venv)"
  echo
  echo "To start Svelte development server:"
  echo -e "  ${BLUE}cd $FRONTEND_DIR${NC}"
  echo -e "  ${BLUE}bun run dev${NC}  # or npm run dev"
  echo
  echo "For production:"
  echo -e "  ${BLUE}cd $FRONTEND_DIR${NC}"
  echo -e "  ${BLUE}bun run build${NC}  # or npm run build"
  echo -e "  ${BLUE}cd $BACKEND_DIR${NC}"
  echo -e "  ${BLUE}python main.py${NC}"
  echo
  echo -e "${YELLOW}Note:${NC} The backend server runs on http://localhost:8000"
  echo -e "${YELLOW}Note:${NC} The Svelte dev server typically runs on http://localhost:5173"
}

# Main setup flow
main() {
  section "Setup for svelte-fastapi-pycrdt-websocket"
  echo "This script will set up both Python backend and Svelte frontend environments."
  
  check_python
  setup_uv
  setup_bun
  setup_svelte
  build_frontend
  show_instructions
}

# Run the main function
main
