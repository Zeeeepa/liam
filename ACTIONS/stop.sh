#!/usr/bin/env bash

################################################################################
# Liam Stop Script
#
# This script gracefully stops all Liam services:
# - Main application server
# - Documentation site
# - MCP server
# - Any orphaned Node.js processes
#
# Usage:
#   ./stop.sh [OPTIONS]
#
# Options:
#   --force       Force kill all processes (no graceful shutdown)
#   --app-only    Stop only the main application
#   --docs-only   Stop only the documentation site
#   --mcp-only    Stop only the MCP server
#   --clean       Remove PID files and log files
#   --help        Show this help message
#
# Examples:
#   ./stop.sh                # Stop all services gracefully
#   ./stop.sh --force        # Force stop all services
#   ./stop.sh --clean        # Stop and clean up files
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
FORCE=false
STOP_APP=true
STOP_DOCS=true
STOP_MCP=true
CLEAN=false

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

################################################################################
# Parse Arguments
################################################################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
                shift
                ;;
            --app-only)
                STOP_APP=true
                STOP_DOCS=false
                STOP_MCP=false
                shift
                ;;
            --docs-only)
                STOP_APP=false
                STOP_DOCS=true
                STOP_MCP=false
                shift
                ;;
            --mcp-only)
                STOP_APP=false
                STOP_DOCS=false
                STOP_MCP=true
                shift
                ;;
            --clean)
                CLEAN=true
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
# PID Management
################################################################################

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

remove_pid_file() {
    local service=$1
    if [ -f "$PID_DIR/$service.pid" ]; then
        rm -f "$PID_DIR/$service.pid"
    fi
}

################################################################################
# Process Management
################################################################################

stop_service() {
    local service=$1
    local display_name=$2
    
    log_info "Stopping $display_name..."
    
    local pid
    pid=$(get_pid "$service")
    
    if [ -z "$pid" ]; then
        log_warning "$display_name: No PID file found"
        return 0
    fi
    
    if ! kill -0 "$pid" 2>/dev/null; then
        log_warning "$display_name: Process not running (PID: $pid)"
        remove_pid_file "$service"
        return 0
    fi
    
    if [ "$FORCE" = true ]; then
        # Force kill
        log_info "Force killing $display_name (PID: $pid)..."
        kill -9 "$pid" 2>/dev/null || true
        sleep 1
    else
        # Graceful shutdown
        log_info "Sending SIGTERM to $display_name (PID: $pid)..."
        kill -TERM "$pid" 2>/dev/null || true
        
        # Wait for graceful shutdown (max 10 seconds)
        local attempts=0
        while kill -0 "$pid" 2>/dev/null && [ $attempts -lt 10 ]; do
            sleep 1
            attempts=$((attempts + 1))
            echo -n "."
        done
        echo ""
        
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "$display_name did not stop gracefully, force killing..."
            kill -9 "$pid" 2>/dev/null || true
            sleep 1
        fi
    fi
    
    # Verify process stopped
    if kill -0 "$pid" 2>/dev/null; then
        log_error "Failed to stop $display_name (PID: $pid)"
        return 1
    else
        log_success "$display_name stopped"
        remove_pid_file "$service"
        return 0
    fi
}

stop_by_port() {
    local port=$1
    local service_name=$2
    
    log_info "Stopping $service_name on port $port..."
    
    local pids
    pids=$(lsof -ti:$port 2>/dev/null || true)
    
    if [ -z "$pids" ]; then
        log_info "No processes found on port $port"
        return 0
    fi
    
    for pid in $pids; do
        if [ "$FORCE" = true ]; then
            kill -9 "$pid" 2>/dev/null || true
        else
            kill -TERM "$pid" 2>/dev/null || true
            sleep 1
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
    done
    
    sleep 1
    
    # Verify
    if lsof -ti:$port >/dev/null 2>&1; then
        log_error "Failed to stop $service_name on port $port"
        return 1
    else
        log_success "$service_name stopped"
        return 0
    fi
}

stop_all_node_processes() {
    log_section "Stopping All Node.js Processes"
    
    log_warning "This will stop ALL Node.js processes in the project"
    
    # Find all node processes in project directory
    local pids
    pids=$(pgrep -f "node.*$PROJECT_ROOT" 2>/dev/null || true)
    
    if [ -z "$pids" ]; then
        log_info "No Node.js processes found"
        return 0
    fi
    
    log_info "Found $(echo "$pids" | wc -l) Node.js process(es)"
    
    for pid in $pids; do
        local cmd
        cmd=$(ps -p "$pid" -o cmd= 2>/dev/null || echo "unknown")
        log_info "Stopping: $cmd (PID: $pid)"
        
        if [ "$FORCE" = true ]; then
            kill -9 "$pid" 2>/dev/null || true
        else
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done
    
    sleep 2
    
    # Force kill any remaining
    pids=$(pgrep -f "node.*$PROJECT_ROOT" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        log_warning "Some processes still running, force killing..."
        echo "$pids" | xargs kill -9 2>/dev/null || true
    fi
    
    log_success "All Node.js processes stopped"
}

################################################################################
# Cleanup
################################################################################

cleanup_files() {
    log_section "Cleanup"
    
    # Remove PID files
    if [ -d "$PID_DIR" ]; then
        log_info "Removing PID files..."
        rm -rf "$PID_DIR"
        log_success "PID files removed"
    fi
    
    # Remove log files
    if ls "$PROJECT_ROOT"/.liam-*.log >/dev/null 2>&1; then
        log_info "Removing log files..."
        rm -f "$PROJECT_ROOT"/.liam-*.log
        log_success "Log files removed"
    fi
    
    # Remove Next.js cache (optional)
    if [ -d "$PROJECT_ROOT/frontend/apps/app/.next/cache" ]; then
        log_info "Clearing Next.js cache..."
        rm -rf "$PROJECT_ROOT/frontend/apps/app/.next/cache"
        log_success "Next.js cache cleared"
    fi
}

################################################################################
# Service Stopping
################################################################################

stop_services() {
    log_section "Stopping Services"
    
    local stopped=false
    
    if [ "$STOP_APP" = true ]; then
        if is_running "app"; then
            stop_service "app" "Main Application"
            stopped=true
        else
            # Try by port as fallback
            if lsof -ti:3001 >/dev/null 2>&1; then
                stop_by_port 3001 "Main Application"
                stopped=true
            else
                log_info "Main Application is not running"
            fi
        fi
    fi
    
    if [ "$STOP_DOCS" = true ]; then
        if is_running "docs"; then
            stop_service "docs" "Documentation Site"
            stopped=true
        else
            # Try by port as fallback
            if lsof -ti:3002 >/dev/null 2>&1; then
                stop_by_port 3002 "Documentation Site"
                stopped=true
            else
                log_info "Documentation Site is not running"
            fi
        fi
    fi
    
    if [ "$STOP_MCP" = true ]; then
        if is_running "mcp"; then
            stop_service "mcp" "MCP Server"
            stopped=true
        else
            log_info "MCP Server is not running"
        fi
    fi
    
    if [ "$stopped" = false ]; then
        log_warning "No services were running"
    fi
}

################################################################################
# Verification
################################################################################

verify_stopped() {
    log_section "Verification"
    
    local all_stopped=true
    
    # Check common ports
    for port in 3001 3002; do
        if lsof -ti:$port >/dev/null 2>&1; then
            log_error "Port $port is still in use"
            all_stopped=false
        fi
    done
    
    # Check for any remaining node processes
    local pids
    pids=$(pgrep -f "node.*$PROJECT_ROOT" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        log_error "Some Node.js processes still running:"
        echo "$pids" | while read -r pid; do
            ps -p "$pid" -o pid,cmd
        done
        all_stopped=false
    fi
    
    if [ "$all_stopped" = true ]; then
        log_success "All services stopped successfully"
    else
        log_warning "Some services may still be running"
        log_info "Use --force to force stop all processes"
    fi
}

################################################################################
# Display Final Status
################################################################################

display_final_status() {
    log_section "Stop Complete"
    
    cat <<EOF
$(echo -e "${GREEN}")
╔═══════════════════════════════════════════════════════════════╗
║                 LIAM SERVICES STOPPED                          ║
╚═══════════════════════════════════════════════════════════════╝
$(echo -e "${NC}")

$(echo -e "${BLUE}📊 Status:${NC}")
EOF
    
    if [ "$STOP_APP" = true ]; then
        echo "  ✅ Main Application stopped"
    fi
    
    if [ "$STOP_DOCS" = true ]; then
        echo "  ✅ Documentation Site stopped"
    fi
    
    if [ "$STOP_MCP" = true ]; then
        echo "  ✅ MCP Server stopped"
    fi
    
    if [ "$CLEAN" = true ]; then
        echo "  ✅ Cleanup completed"
    fi
    
    cat <<EOF

$(echo -e "${BLUE}🚀 To restart:${NC}")
  ./ACTIONS/start.sh

$(echo -e "${BLUE}📚 Documentation:${NC}")
  ./ACTIONS/INSTRUCTIONS.md

$(echo -e "${GREEN}All services stopped! 👋${NC}")

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
║                    LIAM STOP SCRIPT                            ║
║                   AI Database Schema Designer                  ║
╚═══════════════════════════════════════════════════════════════╝
$(echo -e "${NC}")

EOF
    
    # Stop services
    stop_services
    
    # Cleanup if requested
    if [ "$CLEAN" = true ]; then
        cleanup_files
    fi
    
    # Verify all stopped
    verify_stopped
    
    # Display final status
    display_final_status
}

# Run main function
main "$@"

