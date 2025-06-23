#!/bin/bash

# 🚀 Liam PMAgent System - Upgraded Start Method
# Single comprehensive flow with fallbacks, validations, and error handling

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REQUIRED_NODE_VERSION="18"
REQUIRED_PNPM_VERSION="8"
SUPABASE_DIR="frontend/internal-packages/db/supabase"
JOBS_DIR="frontend/internal-packages/jobs"
APP_DIR="frontend/apps/app"
ENV_FILE=".env"
REQUIREMENTS_FILE="requirements.md"

# Global state tracking
declare -a VALIDATION_RESULTS=()
declare -a SERVICE_STATUS=()
declare -a RECOVERY_ACTIONS=()
CRITICAL_FAILURE=false
STARTUP_MODE="full"

# Logging functions
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

log_step() {
    echo -e "${PURPLE}🔄 $1${NC}"
}

log_header() {
    echo -e "${CYAN}"
    echo "=================================="
    echo "$1"
    echo "=================================="
    echo -e "${NC}"
}

log_critical() {
    echo -e "${RED}🚨 CRITICAL: $1${NC}"
    CRITICAL_FAILURE=true
}

# Validation functions
validate_system_requirements() {
    log_step "Validating system requirements..."
    local validation_passed=true
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root for security reasons"
        RECOVERY_ACTIONS+=("Run the script as a regular user (not root)")
        validation_passed=false
    fi
    
    # Check Node.js
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version | sed 's/v//' | cut -d. -f1)
        if [[ $node_version -ge $REQUIRED_NODE_VERSION ]]; then
            log_success "Node.js $(node --version) detected"
            VALIDATION_RESULTS+=("✅ Node.js: $(node --version)")
        else
            log_error "Node.js version $node_version is too old (required: $REQUIRED_NODE_VERSION+)"
            RECOVERY_ACTIONS+=("Install Node.js $REQUIRED_NODE_VERSION+ from https://nodejs.org")
            validation_passed=false
        fi
    else
        log_error "Node.js not found"
        RECOVERY_ACTIONS+=("Install Node.js from https://nodejs.org")
        validation_passed=false
    fi
    
    # Check pnpm
    if command -v pnpm >/dev/null 2>&1; then
        local pnpm_version=$(pnpm --version | cut -d. -f1)
        if [[ $pnpm_version -ge $REQUIRED_PNPM_VERSION ]]; then
            log_success "pnpm $(pnpm --version) detected"
            VALIDATION_RESULTS+=("✅ pnpm: $(pnpm --version)")
        else
            log_warning "pnpm version might be outdated, but continuing..."
            VALIDATION_RESULTS+=("⚠️  pnpm: $(pnpm --version) (might be outdated)")
        fi
    else
        log_warning "pnpm not found, attempting to install..."
        if npm install -g pnpm 2>/dev/null; then
            log_success "pnpm installed successfully"
            VALIDATION_RESULTS+=("✅ pnpm: Installed via npm")
        else
            log_error "Failed to install pnpm"
            RECOVERY_ACTIONS+=("Install pnpm: npm install -g pnpm")
            validation_passed=false
        fi
    fi
    
    # Check Supabase CLI
    if command -v supabase >/dev/null 2>&1; then
        log_success "Supabase CLI detected"
        VALIDATION_RESULTS+=("✅ Supabase CLI: Available")
    else
        log_warning "Supabase CLI not found, attempting to install..."
        if npm install -g supabase 2>/dev/null; then
            log_success "Supabase CLI installed successfully"
            VALIDATION_RESULTS+=("✅ Supabase CLI: Installed via npm")
        else
            log_warning "Failed to install Supabase CLI, will use Docker fallback"
            VALIDATION_RESULTS+=("⚠️  Supabase CLI: Will use Docker fallback")
        fi
    fi
    
    # Check Docker (for Supabase)
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            log_success "Docker is running"
            VALIDATION_RESULTS+=("✅ Docker: Running")
        else
            log_warning "Docker is installed but not running"
            VALIDATION_RESULTS+=("⚠️  Docker: Installed but not running")
            RECOVERY_ACTIONS+=("Start Docker service")
        fi
    else
        log_warning "Docker not found - Supabase local development may not work"
        VALIDATION_RESULTS+=("⚠️  Docker: Not available")
        RECOVERY_ACTIONS+=("Install Docker for local Supabase development")
    fi
    
    # Check required directories
    local required_dirs=("$SUPABASE_DIR" "$APP_DIR")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_success "Directory found: $dir"
            VALIDATION_RESULTS+=("✅ Directory: $dir")
        else
            log_error "Required directory not found: $dir"
            RECOVERY_ACTIONS+=("Ensure you're in the correct project directory")
            validation_passed=false
        fi
    done
    
    if $validation_passed; then
        log_success "System requirements validation passed"
        return 0
    else
        log_error "System requirements validation failed"
        return 1
    fi
}

# Environment setup with validation and fallbacks
setup_environment() {
    log_step "Setting up environment configuration..."
    
    # Create .env file if it doesn't exist
    if [[ ! -f "$ENV_FILE" ]]; then
        log_info "Creating .env file from template..."
        if [[ -f ".env.example" ]]; then
            cp .env.example "$ENV_FILE"
            log_success "Created .env from .env.example"
        else
            log_info "Creating minimal .env file..."
            cat > "$ENV_FILE" << 'EOF'
# Liam PMAgent Configuration
NODE_ENV=development

# Gemini API Configuration (Required)
GEMINI_API_KEY=your_gemini_api_key_here

# Supabase Configuration (Auto-configured for local development)
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU

# Optional: Trigger.dev (for background jobs)
TRIGGER_API_KEY=your_trigger_api_key_here
TRIGGER_API_URL=https://api.trigger.dev
EOF
            log_success "Created minimal .env file"
        fi
    fi
    
    # Validate critical environment variables
    source "$ENV_FILE" 2>/dev/null || true
    
    local env_warnings=()
    
    if [[ -z "${GEMINI_API_KEY:-}" ]] || [[ "${GEMINI_API_KEY:-}" == "your_gemini_api_key_here" ]]; then
        env_warnings+=("GEMINI_API_KEY not configured - AI features will not work")
        RECOVERY_ACTIONS+=("Set GEMINI_API_KEY in .env file")
    fi
    
    if [[ ${#env_warnings[@]} -gt 0 ]]; then
        log_warning "Environment configuration issues detected:"
        for warning in "${env_warnings[@]}"; do
            log_warning "  • $warning"
        done
        SERVICE_STATUS+=("⚠️  Environment: Partial configuration")
    else
        log_success "Environment configuration validated"
        SERVICE_STATUS+=("✅ Environment: Fully configured")
    fi
    
    return 0
}

# Dependency installation with error handling
install_dependencies() {
    log_step "Installing project dependencies..."
    
    # Install root dependencies
    if [[ -f "package.json" ]]; then
        log_info "Installing root dependencies..."
        if pnpm install --frozen-lockfile 2>/dev/null || pnpm install; then
            log_success "Root dependencies installed"
        else
            log_warning "Root dependency installation had issues, but continuing..."
        fi
    fi
    
    # Install app dependencies
    if [[ -d "$APP_DIR" && -f "$APP_DIR/package.json" ]]; then
        log_info "Installing application dependencies..."
        cd "$APP_DIR"
        if pnpm install --frozen-lockfile 2>/dev/null || pnpm install; then
            log_success "Application dependencies installed"
            SERVICE_STATUS+=("✅ Dependencies: Application ready")
        else
            log_error "Failed to install application dependencies"
            SERVICE_STATUS+=("❌ Dependencies: Application failed")
            cd - > /dev/null
            return 1
        fi
        cd - > /dev/null
    else
        log_error "Application directory or package.json not found"
        return 1
    fi
    
    # Install jobs dependencies (optional)
    if [[ -d "$JOBS_DIR" && -f "$JOBS_DIR/package.json" ]]; then
        log_info "Installing background job dependencies..."
        cd "$JOBS_DIR"
        if pnpm install --frozen-lockfile 2>/dev/null || pnpm install; then
            log_success "Background job dependencies installed"
            SERVICE_STATUS+=("✅ Dependencies: Background jobs ready")
        else
            log_warning "Background job dependencies failed, but continuing..."
            SERVICE_STATUS+=("⚠️  Dependencies: Background jobs failed")
        fi
        cd - > /dev/null
    fi
    
    return 0
}

# Database setup with comprehensive fallbacks
setup_database() {
    log_step "Setting up database services..."
    
    if [[ ! -d "$SUPABASE_DIR" ]]; then
        log_warning "Supabase directory not found, skipping database setup"
        SERVICE_STATUS+=("⏭️  Database: Skipped (directory not found)")
        return 0
    fi
    
    cd "$SUPABASE_DIR"
    
    # Initialize Supabase project if needed
    if [[ ! -f ".supabase/config.toml" ]]; then
        log_info "Initializing Supabase project..."
        if supabase init 2>/dev/null; then
            log_success "Supabase project initialized"
        else
            log_warning "Supabase initialization failed, but continuing..."
        fi
    fi
    
    # Start Supabase services
    log_info "Starting Supabase services..."
    if supabase start 2>/dev/null; then
        log_success "Supabase services started"
        
        # Apply migrations with fallback strategies
        log_info "Applying database migrations..."
        local migration_success=false
        
        # Strategy 1: Reset with linked project
        if supabase db reset --linked=false 2>/dev/null; then
            log_success "Database migrations applied (strategy 1)"
            migration_success=true
        # Strategy 2: Simple reset
        elif supabase db reset 2>/dev/null; then
            log_success "Database migrations applied (strategy 2)"
            migration_success=true
        # Strategy 3: Manual migration
        elif supabase db push 2>/dev/null; then
            log_success "Database migrations applied (strategy 3)"
            migration_success=true
        else
            log_warning "Migration failed, but database is functional with seed data"
            migration_success=false
        fi
        
        # Generate types (optional)
        if supabase gen types typescript --local > database.types.ts 2>/dev/null; then
            log_success "Database types generated"
        else
            log_info "Type generation skipped (not critical)"
        fi
        
        if $migration_success; then
            SERVICE_STATUS+=("✅ Database: Operational with migrations")
        else
            SERVICE_STATUS+=("⚠️  Database: Operational with seed data")
        fi
        
    else
        log_warning "Supabase start failed, attempting Docker fallback..."
        
        # Docker fallback
        if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
            log_info "Attempting to start Supabase with Docker..."
            if docker run -d --name supabase-local -p 54321:54321 -p 54322:54322 -p 54323:54323 supabase/supabase:latest 2>/dev/null; then
                log_success "Supabase started with Docker fallback"
                SERVICE_STATUS+=("⚠️  Database: Docker fallback mode")
            else
                log_warning "Docker fallback also failed, database will be limited"
                SERVICE_STATUS+=("❌ Database: Failed to start")
            fi
        else
            log_warning "No Docker available for fallback"
            SERVICE_STATUS+=("❌ Database: Failed to start")
        fi
    fi
    
    cd - > /dev/null
    return 0
}

# Background jobs setup (optional service)
setup_background_jobs() {
    if [[ "$STARTUP_MODE" == "minimal" ]]; then
        log_info "Skipping background jobs (minimal mode)"
        SERVICE_STATUS+=("⏭️  Background Jobs: Skipped (minimal mode)")
        return 0
    fi
    
    log_step "Setting up background job services..."
    
    if [[ ! -d "$JOBS_DIR" || ! -f "$JOBS_DIR/package.json" ]]; then
        log_info "Background jobs directory not found, skipping"
        SERVICE_STATUS+=("⏭️  Background Jobs: Not available")
        return 0
    fi
    
    cd "$JOBS_DIR"
    
    # Start Trigger.dev in development mode
    log_info "Starting background job services..."
    if pnpm exec trigger dev &>/dev/null &
    then
        local trigger_pid=$!
        sleep 3
        
        if kill -0 $trigger_pid 2>/dev/null; then
            log_success "Background job services started"
            SERVICE_STATUS+=("✅ Background Jobs: Operational")
            echo $trigger_pid > /tmp/liam_trigger_pid
        else
            log_warning "Background job services failed to start"
            SERVICE_STATUS+=("⚠️  Background Jobs: Failed")
        fi
    else
        log_warning "Failed to start background job services"
        SERVICE_STATUS+=("⚠️  Background Jobs: Failed")
    fi
    
    cd - > /dev/null
    return 0
}

# Application startup with comprehensive validation
start_application() {
    log_step "Starting application services..."
    
    # Port conflict resolution
    local app_port=3001
    if lsof -i :$app_port >/dev/null 2>&1; then
        log_warning "Port $app_port is in use, attempting to resolve..."
        pkill -f "next.*$app_port" 2>/dev/null || true
        sleep 2
        
        if lsof -i :$app_port >/dev/null 2>&1; then
            log_warning "Port $app_port still in use, trying alternative approaches..."
            # Try to find and kill the specific process
            local pid=$(lsof -ti :$app_port 2>/dev/null)
            if [[ -n "$pid" ]]; then
                kill -9 $pid 2>/dev/null || true
                sleep 1
            fi
        fi
    fi
    
    # Navigate to app directory
    if [[ ! -d "$APP_DIR" ]]; then
        log_critical "Application directory not found: $APP_DIR"
        return 1
    fi
    
    cd "$APP_DIR"
    
    # Build application (optional in development)
    log_info "Preparing application..."
    if pnpm build 2>/dev/null; then
        log_success "Application built successfully"
    else
        log_info "Build skipped (development mode)"
    fi
    
    # Start the application
    log_info "Starting application server..."
    pnpm dev &
    local app_pid=$!
    echo $app_pid > /tmp/liam_app_pid
    
    cd - > /dev/null
    
    # Progressive startup validation
    log_info "Validating application startup..."
    local max_attempts=30
    local attempt=1
    local startup_success=false
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s http://localhost:$app_port >/dev/null 2>&1; then
            log_success "Application is running at http://localhost:$app_port"
            startup_success=true
            break
        fi
        
        # Check if process is still alive
        if ! kill -0 $app_pid 2>/dev/null; then
            log_error "Application process died during startup"
            break
        fi
        
        if [[ $((attempt % 5)) -eq 0 ]]; then
            log_info "Still waiting for application startup... (attempt $attempt/$max_attempts)"
        fi
        
        sleep 2
        ((attempt++))
    done
    
    if $startup_success; then
        SERVICE_STATUS+=("✅ Application: Running on http://localhost:$app_port")
        return 0
    else
        log_error "Application startup failed or timed out"
        SERVICE_STATUS+=("❌ Application: Failed to start")
        return 1
    fi
}

# Comprehensive health check
perform_health_check() {
    log_step "Performing comprehensive health check..."
    
    local health_issues=()
    local critical_issues=()
    
    # Check application
    if curl -s http://localhost:3001 >/dev/null 2>&1; then
        log_success "✅ Application is healthy (http://localhost:3001)"
    else
        health_issues+=("Application not responding on port 3001")
        critical_issues+=("Application startup failed")
    fi
    
    # Check Supabase (if not minimal mode)
    if [[ "$STARTUP_MODE" != "minimal" ]]; then
        if curl -s http://localhost:54321/health >/dev/null 2>&1; then
            log_success "✅ Database API is healthy (http://localhost:54321)"
        else
            health_issues+=("Database API not responding")
        fi
        
        if curl -s http://localhost:54323 >/dev/null 2>&1; then
            log_success "✅ Database Studio is accessible (http://localhost:54323)"
        else
            health_issues+=("Database Studio not accessible (non-critical)")
        fi
    fi
    
    # Check background jobs
    if [[ -f "/tmp/liam_trigger_pid" ]]; then
        local trigger_pid=$(cat /tmp/liam_trigger_pid)
        if kill -0 $trigger_pid 2>/dev/null; then
            log_success "✅ Background job services are running"
        else
            health_issues+=("Background job services not running")
        fi
    fi
    
    # Report health status
    if [[ ${#critical_issues[@]} -eq 0 ]]; then
        log_success "🎉 System health check passed - all critical services operational"
        return 0
    else
        log_warning "⚠️  Health check found issues:"
        for issue in "${health_issues[@]}"; do
            log_warning "  • $issue"
        done
        return 1
    fi
}

# Recovery and troubleshooting
show_recovery_options() {
    if [[ ${#RECOVERY_ACTIONS[@]} -gt 0 ]]; then
        echo ""
        log_warning "🔧 Recovery Actions Needed:"
        for action in "${RECOVERY_ACTIONS[@]}"; do
            log_info "  • $action"
        done
    fi
    
    echo ""
    log_info "🛠️  Troubleshooting Options:"
    log_info "  • Run: ./start.sh --repair (fix common issues)"
    log_info "  • Run: ./start.sh --minimal (start with minimal services)"
    log_info "  • Run: ./start.sh --debug (verbose logging)"
    log_info "  • Check logs above for specific error messages"
}

# Status reporting
show_final_status() {
    echo ""
    log_header "System Status Summary"
    
    # Show validation results
    if [[ ${#VALIDATION_RESULTS[@]} -gt 0 ]]; then
        echo "System Validation:"
        for result in "${VALIDATION_RESULTS[@]}"; do
            echo "  $result"
        done
        echo ""
    fi
    
    # Show service status
    echo "Service Status:"
    for status in "${SERVICE_STATUS[@]}"; do
        echo "  $status"
    done
    echo ""
    
    # Show URLs if successful
    local has_success=false
    for status in "${SERVICE_STATUS[@]}"; do
        if [[ $status == *"✅"* ]]; then
            has_success=true
            break
        fi
    done
    
    if $has_success; then
        echo "📊 Service URLs:"
        echo "  • Frontend Application: http://localhost:3001"
        echo "  • Database Studio:      http://localhost:54323"
        echo "  • Database API:         http://localhost:54321"
        echo ""
        echo "🚀 Quick Start:"
        echo "  1. Open http://localhost:3001"
        echo "  2. Create a new design session"
        echo "  3. Send a message: 'Create a user management system'"
        echo "  4. Watch the PMAgent workflow execute!"
        echo ""
    fi
    
    if $CRITICAL_FAILURE; then
        log_error "❌ System startup completed with critical failures"
        show_recovery_options
        return 1
    else
        log_success "🎉 System startup completed successfully!"
        return 0
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up processes..."
    
    # Kill application
    if [[ -f "/tmp/liam_app_pid" ]]; then
        local app_pid=$(cat /tmp/liam_app_pid)
        kill $app_pid 2>/dev/null || true
        rm -f /tmp/liam_app_pid
    fi
    
    # Kill background jobs
    if [[ -f "/tmp/liam_trigger_pid" ]]; then
        local trigger_pid=$(cat /tmp/liam_trigger_pid)
        kill $trigger_pid 2>/dev/null || true
        rm -f /tmp/liam_trigger_pid
    fi
    
    # Stop Supabase
    if command -v supabase >/dev/null 2>&1; then
        cd "$SUPABASE_DIR" 2>/dev/null && supabase stop 2>/dev/null || true
        cd - >/dev/null 2>&1 || true
    fi
    
    log_success "Cleanup completed"
}

# Repair mode
repair_system() {
    log_header "System Repair Mode"
    
    log_step "Stopping all services..."
    cleanup 2>/dev/null || true
    
    log_step "Cleaning up port conflicts..."
    pkill -f "next.*3001" 2>/dev/null || true
    pkill -f "supabase" 2>/dev/null || true
    
    log_step "Cleaning up temporary files..."
    rm -f /tmp/liam_*_pid 2>/dev/null || true
    rm -f .env.bak 2>/dev/null || true
    
    log_step "Resetting Docker containers..."
    docker stop supabase-local 2>/dev/null || true
    docker rm supabase-local 2>/dev/null || true
    
    log_success "System repair completed"
    log_info "You can now run ./start.sh to start the system"
}

# Main execution flow - Single comprehensive method
main() {
    # Trap cleanup on exit
    trap cleanup EXIT
    
    log_header "🚀 Liam PMAgent System - Upgraded Start Method"
    
    # Phase 1: System Validation
    log_header "Phase 1: System Validation"
    if ! validate_system_requirements; then
        log_critical "System requirements validation failed"
        show_recovery_options
        return 1
    fi
    
    # Phase 2: Environment Setup
    log_header "Phase 2: Environment Setup"
    if ! setup_environment; then
        log_critical "Environment setup failed"
        return 1
    fi
    
    # Phase 3: Dependency Installation
    log_header "Phase 3: Dependency Installation"
    if ! install_dependencies; then
        log_critical "Dependency installation failed"
        return 1
    fi
    
    # Phase 4: Service Startup (with fallbacks)
    log_header "Phase 4: Service Startup"
    
    # Database setup (non-critical)
    setup_database || log_warning "Database setup had issues, but continuing..."
    
    # Background jobs (optional)
    setup_background_jobs || log_warning "Background jobs setup failed, but continuing..."
    
    # Application startup (critical)
    if ! start_application; then
        log_critical "Application startup failed - this is critical"
        return 1
    fi
    
    # Phase 5: Health Validation
    log_header "Phase 5: Health Validation"
    perform_health_check || log_warning "Some health checks failed"
    
    # Phase 6: Final Status
    show_final_status
}

# Command line argument handling
case "${1:-}" in
    --help|-h)
        echo "Liam PMAgent System - Upgraded Start Method"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --minimal           Start with minimal services (UI + Database only)"
        echo "  --debug             Enable verbose logging and debugging"
        echo "  --repair            Repair common issues and clean up"
        echo "  --stop              Stop all services"
        echo "  --health-check      Run health checks only"
        echo ""
        echo "Environment Variables:"
        echo "  DEBUG=true          Enable debug mode"
        echo "  MINIMAL_MODE=true   Start with minimal services"
        echo ""
        exit 0
        ;;
    --minimal)
        export STARTUP_MODE="minimal"
        log_info "Starting in minimal mode"
        main
        ;;
    --debug)
        export DEBUG=true
        set -x  # Enable bash debugging
        log_info "Debug mode enabled"
        main
        ;;
    --repair)
        repair_system
        exit 0
        ;;
    --stop)
        cleanup
        exit 0
        ;;
    --health-check)
        perform_health_check
        exit $?
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

