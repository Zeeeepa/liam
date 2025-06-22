#!/bin/bash

# 🚀 Liam PMAgent System - Automated Setup and Launch Script
# This script sets up and launches the complete Liam system with Gemini API integration

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

# Cleanup function for graceful shutdown
cleanup() {
    log_warning "Shutting down services..."
    
    # Kill background processes
    if [[ -n $SUPABASE_PID ]]; then
        kill $SUPABASE_PID 2>/dev/null || true
    fi
    if [[ -n $TRIGGER_PID ]]; then
        kill $TRIGGER_PID 2>/dev/null || true
    fi
    if [[ -n $APP_PID ]]; then
        kill $APP_PID 2>/dev/null || true
    fi
    
    # Stop Supabase
    if command -v supabase &> /dev/null; then
        cd "$SUPABASE_DIR" && supabase stop 2>/dev/null || true
    fi
    
    log_info "Cleanup completed"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Check if running as root (not recommended)
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root is not recommended for development"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Check system requirements
check_system_requirements() {
    log_header "Checking System Requirements"
    
    # Check Node.js
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ $NODE_VERSION -ge $REQUIRED_NODE_VERSION ]]; then
            log_success "Node.js $(node --version) is installed"
        else
            log_error "Node.js version $REQUIRED_NODE_VERSION or higher is required. Found: $(node --version)"
            exit 1
        fi
    else
        log_error "Node.js is not installed. Please install Node.js $REQUIRED_NODE_VERSION or higher"
        exit 1
    fi
    
    # Check pnpm
    if command -v pnpm &> /dev/null; then
        PNPM_VERSION=$(pnpm --version | cut -d'.' -f1)
        if [[ $PNPM_VERSION -ge $REQUIRED_PNPM_VERSION ]]; then
            log_success "pnpm $(pnpm --version) is installed"
        else
            log_error "pnpm version $REQUIRED_PNPM_VERSION or higher is required. Found: $(pnpm --version)"
            exit 1
        fi
    else
        log_error "pnpm is not installed. Please install pnpm: npm install -g pnpm"
        exit 1
    fi
    
    # Check Docker
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            log_success "Docker is installed and running"
        else
            log_error "Docker is installed but not running. Please start Docker"
            exit 1
        fi
    else
        log_error "Docker is not installed. Please install Docker for Supabase local development"
        exit 1
    fi
    
    # Check Git
    if command -v git &> /dev/null; then
        log_success "Git is installed"
    else
        log_error "Git is not installed. Please install Git"
        exit 1
    fi
}

# Setup environment variables
setup_environment() {
    log_header "Setting Up Environment Variables"
    
    if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
        log_error "requirements.md file not found. Please ensure it exists in the project root"
        exit 1
    fi
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_step "Creating .env file from requirements.md template"
        
        # Extract environment variables from requirements.md
        grep -E '^[A-Z_]+=.*' "$REQUIREMENTS_FILE" > "$ENV_FILE" 2>/dev/null || true
        
        if [[ ! -s "$ENV_FILE" ]]; then
            log_warning "Could not extract variables from requirements.md. Creating basic .env file"
            cat > "$ENV_FILE" << 'EOF'
# Copy your API keys and configuration here
# See requirements.md for detailed instructions

# MANDATORY VARIABLES
GOOGLE_API_KEY=""
TRIGGER_PROJECT_ID=""
TRIGGER_SECRET_KEY=""
NEXT_PUBLIC_SUPABASE_URL="http://localhost:54321"
NEXT_PUBLIC_SUPABASE_ANON_KEY=""
SUPABASE_SERVICE_ROLE_KEY=""
POSTGRES_URL="postgresql://postgres:postgres@localhost:54322/postgres"
POSTGRES_URL_NON_POOLING="postgresql://postgres:postgres@localhost:54322/postgres"
NEXT_PUBLIC_BASE_URL="http://localhost:3000"
NEXT_PUBLIC_ENV_NAME="development"
MIGRATION_ENABLED="true"

# OPTIONAL VARIABLES
LANGFUSE_BASE_URL="https://cloud.langfuse.com"
LANGFUSE_PUBLIC_KEY=""
LANGFUSE_SECRET_KEY=""
SENTRY_DSN=""
RESEND_API_KEY=""
EOF
        fi
        
        log_warning "Please edit .env file and add your API keys before continuing"
        log_info "Required keys: GOOGLE_API_KEY, TRIGGER_PROJECT_ID, TRIGGER_SECRET_KEY"
        log_info "See requirements.md for detailed setup instructions"
        
        read -p "Press Enter after you've configured your .env file..."
    else
        log_success ".env file already exists"
    fi
    
    # Load environment variables
    if [[ -f "$ENV_FILE" ]]; then
        set -a  # Automatically export all variables
        source "$ENV_FILE"
        set +a
        log_success "Environment variables loaded"
    fi
}

# Validate environment variables
validate_environment() {
    log_header "Validating Environment Configuration"
    
    local errors=0
    
    # Check mandatory variables
    if [[ -z "$GOOGLE_API_KEY" ]]; then
        log_error "GOOGLE_API_KEY is not set"
        ((errors++))
    elif [[ ! "$GOOGLE_API_KEY" =~ ^AIzaSy ]]; then
        log_error "GOOGLE_API_KEY format is invalid (should start with 'AIzaSy')"
        ((errors++))
    else
        log_success "Google API key is configured"
    fi
    
    if [[ -z "$TRIGGER_PROJECT_ID" ]]; then
        log_error "TRIGGER_PROJECT_ID is not set"
        ((errors++))
    elif [[ ! "$TRIGGER_PROJECT_ID" =~ ^proj_ ]]; then
        log_error "TRIGGER_PROJECT_ID format is invalid (should start with 'proj_')"
        ((errors++))
    else
        log_success "Trigger.dev project ID is configured"
    fi
    
    if [[ -z "$TRIGGER_SECRET_KEY" ]]; then
        log_error "TRIGGER_SECRET_KEY is not set"
        ((errors++))
    elif [[ ! "$TRIGGER_SECRET_KEY" =~ ^tr_(dev_|prod_) ]]; then
        log_error "TRIGGER_SECRET_KEY format is invalid (should start with 'tr_dev_' or 'tr_prod_')"
        ((errors++))
    else
        log_success "Trigger.dev secret key is configured"
    fi
    
    # Check optional but recommended variables
    if [[ -z "$LANGFUSE_PUBLIC_KEY" ]] || [[ -z "$LANGFUSE_SECRET_KEY" ]]; then
        log_warning "Langfuse not configured - AI observability will be disabled"
    else
        log_success "Langfuse is configured"
    fi
    
    if [[ -z "$SENTRY_DSN" ]]; then
        log_warning "Sentry not configured - error tracking will be disabled"
    else
        log_success "Sentry is configured"
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Environment validation failed with $errors errors"
        log_info "Please check your .env file and requirements.md for setup instructions"
        exit 1
    fi
    
    log_success "Environment validation passed"
}

# Install dependencies
install_dependencies() {
    log_header "Installing Dependencies"
    
    log_step "Installing project dependencies with pnpm..."
    pnpm install
    
    log_step "Installing Supabase CLI..."
    if ! command -v supabase &> /dev/null; then
        npm install -g supabase
    fi
    
    log_step "Installing Trigger.dev CLI..."
    if ! command -v trigger &> /dev/null; then
        npm install -g @trigger.dev/cli
    fi
    
    log_success "Dependencies installed successfully"
}

# Setup Supabase database
setup_database() {
    log_header "Setting Up Supabase Database"
    
    cd "$SUPABASE_DIR"
    
    # Check if Supabase is already running
    if supabase status &> /dev/null; then
        log_info "Supabase is already running"
    else
        log_step "Starting Supabase local development environment..."
        supabase start
    fi
    
    # Get Supabase credentials
    log_step "Retrieving Supabase credentials..."
    SUPABASE_STATUS=$(supabase status)
    
    # Extract credentials from status output
    ANON_KEY=$(echo "$SUPABASE_STATUS" | grep "anon key" | awk '{print $3}')
    SERVICE_ROLE_KEY=$(echo "$SUPABASE_STATUS" | grep "service_role key" | awk '{print $3}')
    
    if [[ -n "$ANON_KEY" ]] && [[ -n "$SERVICE_ROLE_KEY" ]]; then
        # Update .env file with Supabase keys
        cd - > /dev/null
        
        # Update or add Supabase keys to .env
        if grep -q "NEXT_PUBLIC_SUPABASE_ANON_KEY=" "$ENV_FILE"; then
            sed -i.bak "s|NEXT_PUBLIC_SUPABASE_ANON_KEY=.*|NEXT_PUBLIC_SUPABASE_ANON_KEY=\"$ANON_KEY\"|" "$ENV_FILE"
        else
            echo "NEXT_PUBLIC_SUPABASE_ANON_KEY=\"$ANON_KEY\"" >> "$ENV_FILE"
        fi
        
        if grep -q "SUPABASE_SERVICE_ROLE_KEY=" "$ENV_FILE"; then
            sed -i.bak "s|SUPABASE_SERVICE_ROLE_KEY=.*|SUPABASE_SERVICE_ROLE_KEY=\"$SERVICE_ROLE_KEY\"|" "$ENV_FILE"
        else
            echo "SUPABASE_SERVICE_ROLE_KEY=\"$SERVICE_ROLE_KEY\"" >> "$ENV_FILE"
        fi
        
        # Reload environment variables
        set -a
        source "$ENV_FILE"
        set +a
        
        log_success "Supabase credentials updated in .env file"
    else
        log_warning "Could not extract Supabase credentials automatically"
    fi
    
    # Apply database migrations
    log_step "Applying database migrations..."
    cd "$SUPABASE_DIR"
    supabase db reset --linked=false
    
    # Generate TypeScript types
    log_step "Generating database types..."
    supabase gen types typescript --local > database.types.ts
    
    cd - > /dev/null
    log_success "Database setup completed"
}

# Setup Trigger.dev
setup_trigger_dev() {
    log_header "Setting Up Trigger.dev"
    
    cd "$JOBS_DIR"
    
    # Check if already logged in
    if pnpm exec trigger whoami &> /dev/null; then
        log_success "Already logged in to Trigger.dev"
    else
        log_step "Please log in to Trigger.dev..."
        pnpm exec trigger login
    fi
    
    # Deploy jobs to development environment
    log_step "Deploying jobs to Trigger.dev development environment..."
    pnpm exec trigger dev &
    TRIGGER_PID=$!
    
    # Wait a moment for trigger dev to start
    sleep 5
    
    cd - > /dev/null
    log_success "Trigger.dev setup completed"
}

# Build and start the application
start_application() {
    log_header "Starting Application"
    
    # Build the project
    log_step "Building the project..."
    pnpm build
    
    # Start the frontend application
    log_step "Starting frontend application..."
    cd "$APP_DIR"
    pnpm dev &
    APP_PID=$!
    
    cd - > /dev/null
    
    # Wait for the application to start
    log_step "Waiting for application to start..."
    sleep 10
    
    # Check if the application is running
    if curl -s http://localhost:3000 > /dev/null; then
        log_success "Application is running at http://localhost:3000"
    else
        log_warning "Application may still be starting up..."
    fi
}

# Display service status and URLs
show_status() {
    log_header "Service Status"
    
    echo -e "${GREEN}🎉 Liam PMAgent System is now running!${NC}"
    echo ""
    echo "📊 Service URLs:"
    echo "  • Frontend Application: http://localhost:3000"
    echo "  • Supabase Studio:     http://localhost:54323"
    echo "  • Supabase API:        http://localhost:54321"
    echo "  • Database:            postgresql://postgres:postgres@localhost:54322/postgres"
    echo ""
    echo "🔧 Development Tools:"
    echo "  • Supabase Inbucket:   http://localhost:54324 (Email testing)"
    echo "  • Trigger.dev Dashboard: https://trigger.dev"
    echo ""
    echo "📖 Documentation:"
    echo "  • Project Docs:        https://liambx.com/docs"
    echo "  • Requirements:        ./requirements.md"
    echo ""
    echo "🚀 Quick Test:"
    echo "  1. Open http://localhost:3000"
    echo "  2. Create a new design session"
    echo "  3. Send a message: 'Create a user management system'"
    echo "  4. Watch the PMAgent workflow execute with Gemini API!"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"
}

# Health check function
health_check() {
    log_step "Performing health checks..."
    
    local health_ok=true
    
    # Check frontend
    if curl -s http://localhost:3000 > /dev/null; then
        log_success "Frontend is healthy"
    else
        log_error "Frontend is not responding"
        health_ok=false
    fi
    
    # Check Supabase
    if curl -s http://localhost:54321/health > /dev/null; then
        log_success "Supabase is healthy"
    else
        log_error "Supabase is not responding"
        health_ok=false
    fi
    
    # Check database connection
    if psql "postgresql://postgres:postgres@localhost:54322/postgres" -c "SELECT 1;" &> /dev/null; then
        log_success "Database connection is healthy"
    else
        log_error "Database connection failed"
        health_ok=false
    fi
    
    if $health_ok; then
        log_success "All health checks passed"
    else
        log_warning "Some health checks failed - system may not be fully operational"
    fi
}

# Main execution flow
main() {
    log_header "🚀 Liam PMAgent System Setup"
    echo "This script will set up and launch the complete Liam system with Gemini API integration"
    echo ""
    
    # Check if we should skip confirmation in CI/automated environments
    if [[ "${CI:-false}" != "true" ]] && [[ "${SKIP_CONFIRMATION:-false}" != "true" ]]; then
        read -p "Continue with setup? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Setup cancelled by user"
            exit 0
        fi
    fi
    
    # Execute setup steps
    check_root
    check_system_requirements
    setup_environment
    validate_environment
    install_dependencies
    setup_database
    setup_trigger_dev
    start_application
    
    # Final status and health check
    show_status
    health_check
    
    # Keep the script running to maintain services
    log_info "Setup completed successfully! Services are running..."
    log_info "Monitoring services... (Press Ctrl+C to stop)"
    
    # Monitor services and restart if needed
    while true; do
        sleep 30
        
        # Check if processes are still running
        if [[ -n $APP_PID ]] && ! kill -0 $APP_PID 2>/dev/null; then
            log_warning "Frontend process died, restarting..."
            cd "$APP_DIR"
            pnpm dev &
            APP_PID=$!
            cd - > /dev/null
        fi
        
        if [[ -n $TRIGGER_PID ]] && ! kill -0 $TRIGGER_PID 2>/dev/null; then
            log_warning "Trigger.dev process died, restarting..."
            cd "$JOBS_DIR"
            pnpm exec trigger dev &
            TRIGGER_PID=$!
            cd - > /dev/null
        fi
    done
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Liam PMAgent System Setup Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --skip-confirmation Skip confirmation prompts (useful for CI)"
        echo "  --health-check      Run health checks only"
        echo "  --stop              Stop all services"
        echo ""
        echo "Environment Variables:"
        echo "  CI=true             Skip confirmation prompts"
        echo "  SKIP_CONFIRMATION=true  Skip confirmation prompts"
        echo ""
        exit 0
        ;;
    --skip-confirmation)
        export SKIP_CONFIRMATION=true
        main
        ;;
    --health-check)
        health_check
        exit 0
        ;;
    --stop)
        cleanup
        exit 0
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

