#!/usr/bin/env bash

################################################################################
# Liam Start Script
#
# This script starts the Liam application with intelligent service management:
# - Automatic port conflict detection and resolution
# - Multiple service orchestration (app, docs, MCP server)
# - Health checking and status monitoring
# - Graceful startup with proper initialization
#
# Usage:
#   ./start.sh [OPTIONS]
#
# Options:
#   --app-only        Start only the main application (default: port 3001)
#   --docs-only       Start only the documentation site (default: port 3002)
#   --mcp-only        Start only the MCP server
#   --all             Start all services (app + docs + MCP)
#   --port PORT       Override default port for main app
#   --production      Start in production mode (requires build first)
#   --background      Start services in background
#   --help            Show this help message
#
# Examples:
#   ./start.sh                    # Start main app only (dev mode)
#   ./start.sh --all              # Start all services
#   ./start.sh --production       # Start in production mode
#   ./start.sh --port 3000        # Start on custom port
#
################################################################################

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly PID_DIR="$PROJECT_ROOT/.liam-pids"

# Default settings
START_APP=true
START_DOCS=false
START_MCP=false
APP_PORT=3001
DOCS_PORT=3002
PRODUCTION=false
BACKGROUND=false

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Parse Arguments
################################################################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --app-only)
                START_APP=true
                START_DOCS=false
                START_MCP=false
                shift
                ;;
            --docs-only)
                START_APP=false
                START_DOCS=true
                START_MCP=false
                shift
                ;;
            --mcp-only)
                START_APP=false
                START_DOCS=false
                START_MCP=true
                shift
                ;;
            --all)
                START_APP=true
                START_DOCS=true
                START_MCP=true
                shift
                ;;
            --port)
                APP_PORT="$2"
                shift 2
                ;;
            --production)
                PRODUCTION=true
                shift
                ;;
            --background)
                BACKGROUND=true
                shift
                ;;
            --help)
                grep '^#' "$0" | grep -v '#!/usr/bin/env' | sed 's/^# //'
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

################################################################################
# Prerequisites Check
################################################################################

check_prerequisites() {
    log_section "Prerequisites Check"
    
    # Check Node.js
    if ! check_command node; then
        log_error "Node.js not found"
        log_info "Run: ./ACTIONS/setup.sh"
        exit 1
    fi
    log_success "Node.js $(node -v) found"
    
    # Check pnpm
    if ! check_command pnpm; then
        log_error "pnpm not found"
        log_info "Run: ./ACTIONS/setup.sh"
        exit 1
    fi
    log_success "pnpm v$(pnpm -v) found"
    
    # Check project dependencies
    if [ ! -d "$PROJECT_ROOT/node_modules" ]; then
        log_error "Dependencies not installed"
        log_info "Run: ./ACTIONS/setup.sh"
        exit 1
    fi
    log_success "Project dependencies installed"
    
    # Check environment
    if [ ! -f "$PROJECT_ROOT/.env.local" ]; then
        log_warning ".env.local not found"
        log_info "Creating from template..."
        if [ -f "$PROJECT_ROOT/.env.template" ]; then
            cp "$PROJECT_ROOT/.env.template" "$PROJECT_ROOT/.env.local"
            log_warning "Please configure .env.local before starting"
        fi
    else
        log_success "Environment configuration found"
    fi
    
    # Check production build if needed
    if [ "$PRODUCTION" = true ]; then
        if [ ! -d "$PROJECT_ROOT/frontend/apps/app/.next" ]; then
            log_error "Production build not found"
            log_info "Run: pnpm build --filter @liam-hq/app"
            exit 1
        fi
        log_success "Production build found"
    fi
}

################################################################################
# Port Management
################################################################################

check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

kill_port() {
    local port=$1
    log_warning "Port $port is in use, attempting to free it..."
    
    local pids
    pids=$(lsof -ti:$port 2>/dev/null || true)
    
    if [ -n "$pids" ]; then
        echo "$pids" | xargs kill -9 2>/dev/null || true
        sleep 1
        
        if check_port "$port"; then
            log_error "Failed to free port $port"
            return 1
        else
            log_success "Port $port freed"
            return 0
        fi
    fi
}

find_available_port() {
    local start_port=$1
    local max_attempts=10
    local port=$start_port
    
    for ((i=0; i<max_attempts; i++)); do
        if ! check_port "$port"; then
            echo "$port"
            return 0
        fi
        port=$((port + 1))
    done
    
    log_error "Could not find available port starting from $start_port"
    exit 1
}

################################################################################
# PID Management
################################################################################

setup_pid_dir() {
    mkdir -p "$PID_DIR"
}

save_pid() {
    local service=$1
    local pid=$2
    echo "$pid" > "$PID_DIR/$service.pid"
}

get_pid() {
    local service=$1
    if [ -f "$PID_DIR/$service.pid" ]; then
        cat "$PID_DIR/$service.pid"
    fi
}

is_running() {
    local service=$1
    local pid
    pid=$(get_pid "$service")
    
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Service Management
################################################################################

start_main_app() {
    log_section "Starting Main Application"
    
    # Check if already running
    if is_running "app"; then
        log_warning "Main app is already running"
        return 0
    fi
    
    # Check port availability
    if check_port "$APP_PORT"; then
        log_warning "Port $APP_PORT is in use"
        if ! kill_port "$APP_PORT"; then
            APP_PORT=$(find_available_port "$APP_PORT")
            log_info "Using alternative port: $APP_PORT"
        fi
    fi
    
    cd "$PROJECT_ROOT/frontend/apps/app"
    
    if [ "$PRODUCTION" = true ]; then
        log_info "Starting in production mode on port $APP_PORT..."
        
        if [ "$BACKGROUND" = true ]; then
            PORT=$APP_PORT pnpm start > "$PROJECT_ROOT/.liam-app.log" 2>&1 &
            local pid=$!
            save_pid "app" "$pid"
            log_success "Main app started in background (PID: $pid)"
        else
            PORT=$APP_PORT pnpm start
        fi
    else
        log_info "Starting in development mode on port $APP_PORT..."
        log_info "This may take 10-30 seconds for initial compilation..."
        
        if [ "$BACKGROUND" = true ]; then
            PORT=$APP_PORT pnpm dev > "$PROJECT_ROOT/.liam-app.log" 2>&1 &
            local pid=$!
            save_pid "app" "$pid"
            log_success "Main app started in background (PID: $pid)"
        else
            PORT=$APP_PORT pnpm dev
        fi
    fi
}

start_docs() {
    log_section "Starting Documentation Site"
    
    # Check if already running
    if is_running "docs"; then
        log_warning "Docs site is already running"
        return 0
    fi
    
    # Check port availability
    if check_port "$DOCS_PORT"; then
        log_warning "Port $DOCS_PORT is in use"
        if ! kill_port "$DOCS_PORT"; then
            DOCS_PORT=$(find_available_port "$DOCS_PORT")
            log_info "Using alternative port: $DOCS_PORT"
        fi
    fi
    
    cd "$PROJECT_ROOT/frontend/apps/docs"
    
    if [ "$PRODUCTION" = true ]; then
        log_info "Starting docs in production mode on port $DOCS_PORT..."
        
        if [ "$BACKGROUND" = true ]; then
            PORT=$DOCS_PORT pnpm start > "$PROJECT_ROOT/.liam-docs.log" 2>&1 &
            local pid=$!
            save_pid "docs" "$pid"
            log_success "Docs site started in background (PID: $pid)"
        else
            PORT=$DOCS_PORT pnpm start
        fi
    else
        log_info "Starting docs in development mode on port $DOCS_PORT..."
        
        if [ "$BACKGROUND" = true ]; then
            PORT=$DOCS_PORT pnpm dev > "$PROJECT_ROOT/.liam-docs.log" 2>&1 &
            local pid=$!
            save_pid "docs" "$pid"
            log_success "Docs site started in background (PID: $pid)"
        else
            PORT=$DOCS_PORT pnpm dev
        fi
    fi
}

start_mcp_server() {
    log_section "Starting MCP Server"
    
    # Check if already running
    if is_running "mcp"; then
        log_warning "MCP server is already running"
        return 0
    fi
    
    cd "$PROJECT_ROOT/frontend/internal-packages/mcp-server"
    
    log_info "Starting MCP server..."
    
    if [ "$BACKGROUND" = true ]; then
        pnpm dev > "$PROJECT_ROOT/.liam-mcp.log" 2>&1 &
        local pid=$!
        save_pid "mcp" "$pid"
        log_success "MCP server started in background (PID: $pid)"
    else
        pnpm dev
    fi
}

################################################################################
# Health Check
################################################################################

wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=0
    
    log_info "Waiting for $service_name to be ready..."
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f -o /dev/null "$url" 2>/dev/null; then
            log_success "$service_name is ready!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 1
        echo -n "."
    done
    
    echo ""
    log_warning "$service_name did not respond within 30 seconds"
    return 1
}

perform_health_checks() {
    if [ "$BACKGROUND" = false ]; then
        return 0  # Skip health checks in foreground mode
    fi
    
    log_section "Health Checks"
    
    if [ "$START_APP" = true ]; then
        wait_for_service "http://localhost:$APP_PORT" "Main App"
    fi
    
    if [ "$START_DOCS" = true ]; then
        wait_for_service "http://localhost:$DOCS_PORT" "Docs Site"
    fi
}

################################################################################
# Display Status
################################################################################

display_status() {
    log_section "Liam Status"
    
    cat <<EOF
$(echo -e "${GREEN}")
╔═══════════════════════════════════════════════════════════════╗
║                    LIAM IS RUNNING!                            ║
╚═══════════════════════════════════════════════════════════════╝
$(echo -e "${NC}")

EOF
    
    if [ "$START_APP" = true ]; then
        echo -e "${GREEN}🚀 Main Application${NC}"
        echo -e "   URL: ${CYAN}http://localhost:$APP_PORT${NC}"
        echo -e "   Mode: $([ "$PRODUCTION" = true ] && echo "Production" || echo "Development")"
        echo ""
    fi
    
    if [ "$START_DOCS" = true ]; then
        echo -e "${GREEN}📚 Documentation Site${NC}"
        echo -e "   URL: ${CYAN}http://localhost:$DOCS_PORT${NC}"
        echo ""
    fi
    
    if [ "$START_MCP" = true ]; then
        echo -e "${GREEN}🔌 MCP Server${NC}"
        echo -e "   Status: Running"
        echo ""
    fi
    
    cat <<EOF
$(echo -e "${BLUE}🎯 Quick Test:${NC}")
  1. Open: http://localhost:$APP_PORT
  2. Type: "Create a blog system with users and posts"
  3. Watch the AI agents work! 🤖

$(echo -e "${BLUE}🛠️  Management:${NC}")
  Stop all services: ./ACTIONS/stop.sh
  View logs: tail -f .liam-*.log
  Check status: ps aux | grep node

$(echo -e "${YELLOW}💡 Tips:${NC}")
  - Press Ctrl+C to stop (if running in foreground)
  - First compilation may take 10-30 seconds
  - Hot reload enabled in development mode

$(echo -e "${GREEN}Happy coding! 🎨✨${NC}")

EOF
}

################################################################################
# Main Execution
################################################################################

main() {
    # Parse arguments
    parse_args "$@"
    
    # Print header
    cat <<EOF
$(echo -e "${CYAN}")
╔═══════════════════════════════════════════════════════════════╗
║                    LIAM START SCRIPT                           ║
║                   AI Database Schema Designer                  ║
╚═══════════════════════════════════════════════════════════════╝
$(echo -e "${NC}")

EOF
    
    # Run checks
    check_prerequisites
    
    # Setup PID directory
    setup_pid_dir
    
    # Start services based on flags
    if [ "$START_APP" = true ] && [ "$START_DOCS" = false ] && [ "$START_MCP" = false ]; then
        # Default: just start the app
        start_main_app
    else
        # Start multiple services in background
        BACKGROUND=true
        
        if [ "$START_APP" = true ]; then
            start_main_app
        fi
        
        if [ "$START_DOCS" = true ]; then
            start_docs
        fi
        
        if [ "$START_MCP" = true ]; then
            start_mcp_server
        fi
        
        # Wait for services to be ready
        sleep 3
        perform_health_checks
        
        # Display status
        display_status
        
        # Keep script running if in background mode
        if [ "$BACKGROUND" = true ]; then
            log_info "Services running in background. Use ./ACTIONS/stop.sh to stop."
        fi
    fi
}

# Run main function
main "$@"

