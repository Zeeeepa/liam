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

# Prompt for Google API key
prompt_google_api_key() {
    log_header "Google Gemini API Key Setup"
    
    echo -e "${CYAN}🤖 To use Liam PMAgent with Gemini 2.5 Pro, you need a Google API key${NC}"
    echo -e "${BLUE}📝 Get your free API key from: https://makersuite.google.com/app/apikey${NC}"
    echo ""
    
    # Check if API key is already set in environment or .env file
    local existing_key=""
    if [[ -f "$ENV_FILE" ]]; then
        existing_key=$(grep "^GOOGLE_API_KEY=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    fi
    
    if [[ -n "$existing_key" ]] && [[ "$existing_key" != "" ]] && [[ "$existing_key" =~ ^AIzaSy ]]; then
        log_success "Found existing Google API key in .env file"
        echo -e "${GREEN}✅ Using existing API key: ${existing_key:0:20}...${NC}"
        echo ""
        read -p "Use this existing key? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            existing_key=""
        else
            export GOOGLE_API_KEY="$existing_key"
            return 0
        fi
    fi
    
    # Prompt for new API key
    while true; do
        echo -e "${YELLOW}🔑 Please paste your Google API key:${NC}"
        read -r -p "GOOGLE_API_KEY: " google_api_key
        
        # Validate API key format
        if [[ -z "$google_api_key" ]]; then
            log_error "API key cannot be empty"
            continue
        elif [[ ! "$google_api_key" =~ ^AIzaSy ]]; then
            log_error "Invalid API key format. Google API keys start with 'AIzaSy'"
            echo -e "${BLUE}💡 Make sure you copied the complete key from https://makersuite.google.com/app/apikey${NC}"
            continue
        elif [[ ${#google_api_key} -lt 35 ]] || [[ ${#google_api_key} -gt 45 ]]; then
            log_error "Invalid API key length. Google API keys are typically 39 characters long"
            continue
        else
            log_success "API key format looks valid!"
            break
        fi
    done
    
    # Export the API key for immediate use
    export GOOGLE_API_KEY="$google_api_key"
    
    # Test the API key
    log_step "Testing API key with Gemini 2.5 Pro..."
    local test_result
    test_result=$(curl -s -X POST \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=$google_api_key" \
        -H 'Content-Type: application/json' \
        -d '{
            "contents": [{
                "parts": [{
                    "text": "Respond with just: API Test Successful"
                }]
            }]
        }' 2>/dev/null)
    
    if echo "$test_result" | grep -q "API Test Successful"; then
        log_success "🎉 API key verified! Gemini 2.5 Pro is working perfectly"
    elif echo "$test_result" | grep -q "error"; then
        log_error "API key test failed. Please check your key and try again"
        log_info "Error details: $(echo "$test_result" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)"
        exit 1
    else
        log_warning "API key test inconclusive, but proceeding with setup"
    fi
    
    echo ""
}

# Setup environment variables
setup_environment() {
    log_header "Setting Up Environment Variables"
    
    if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
        log_error "requirements.md file not found. Please ensure it exists in the project root"
        exit 1
    fi
    
    # Always prompt for Google API key first
    prompt_google_api_key
    
    # Create or update .env file
    if [[ ! -f "$ENV_FILE" ]]; then
        log_step "Creating .env file with auto-configured defaults"
        
        # Create .env file with the provided API key and pre-defined values
        cat > "$ENV_FILE" << EOF
# === GOOGLE GEMINI API CONFIGURATION ===
# Google Gemini 2.5 Pro API Key
GOOGLE_API_KEY="$GOOGLE_API_KEY"

# === AUTOMATICALLY CONFIGURED (No Manual Input Required) ===
# Supabase Configuration (AUTO-CONFIGURED)
NEXT_PUBLIC_SUPABASE_URL="http://localhost:54321"
NEXT_PUBLIC_SUPABASE_ANON_KEY="AUTO_RETRIEVED_FROM_SUPABASE_START"
SUPABASE_SERVICE_ROLE_KEY="AUTO_RETRIEVED_FROM_SUPABASE_START"

# Database URLs (AUTO-CONFIGURED)
POSTGRES_URL="postgresql://postgres:postgres@localhost:54322/postgres"
POSTGRES_URL_NON_POOLING="postgresql://postgres:postgres@localhost:54322/postgres"

# Trigger.dev Configuration (AUTO-CONFIGURED for development)
TRIGGER_PROJECT_ID="dev-local-project"
TRIGGER_SECRET_KEY="dev-local-secret"

# Application Configuration (PRE-DEFINED)
NEXT_PUBLIC_BASE_URL="http://localhost:3000"
NEXT_PUBLIC_ENV_NAME="development"
MIGRATION_ENABLED="true"

# === OPTIONAL ENHANCEMENTS ===
# Langfuse (AI Observability) - OPTIONAL
LANGFUSE_BASE_URL="https://cloud.langfuse.com"
LANGFUSE_PUBLIC_KEY=""
LANGFUSE_SECRET_KEY=""

# Sentry (Error Tracking) - OPTIONAL
SENTRY_DSN=""
SENTRY_ORG=""
SENTRY_PROJECT=""
SENTRY_AUTH_TOKEN=""

# Resend (Email Service) - OPTIONAL
RESEND_API_KEY=""
RESEND_EMAIL_FROM_ADDRESS=""

# GitHub Integration - OPTIONAL
GITHUB_APP_ID=""
GITHUB_CLIENT_ID=""
GITHUB_CLIENT_SECRET=""
GITHUB_PRIVATE_KEY=""
NEXT_PUBLIC_GITHUB_APP_URL=""

# Feature Flags - OPTIONAL
FLAGS_SECRET=""
EOF
        
        log_success "✅ .env file created with your Google API key"
    else
        # Update existing .env file with the new API key
        log_step "Updating existing .env file with new Google API key"
        
        if grep -q "^GOOGLE_API_KEY=" "$ENV_FILE"; then
            # Replace existing key
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' "s|^GOOGLE_API_KEY=.*|GOOGLE_API_KEY=\"$GOOGLE_API_KEY\"|" "$ENV_FILE"
            else
                # Linux
                sed -i "s|^GOOGLE_API_KEY=.*|GOOGLE_API_KEY=\"$GOOGLE_API_KEY\"|" "$ENV_FILE"
            fi
        else
            # Add new key at the top
            echo "GOOGLE_API_KEY=\"$GOOGLE_API_KEY\"" | cat - "$ENV_FILE" > temp && mv temp "$ENV_FILE"
        fi
        
        log_success "✅ .env file updated with your Google API key"
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
    
    # Check ONLY mandatory variable - Google API key
    if [[ -z "$GOOGLE_API_KEY" ]]; then
        log_error "GOOGLE_API_KEY is not set"
        log_info "This is the ONLY required manual input. Get your key from: https://makersuite.google.com/app/apikey"
        ((errors++))
    elif [[ ! "$GOOGLE_API_KEY" =~ ^AIzaSy ]]; then
        log_error "GOOGLE_API_KEY format is invalid (should start with 'AIzaSy')"
        ((errors++))
    else
        log_success "Google API key is configured ✅"
    fi
    
    # All other variables are auto-configured or optional
    log_success "Trigger.dev is auto-configured for local development"
    log_success "Supabase will be auto-configured when started"
    log_success "Application settings are pre-defined"
    
    # Check optional enhancements (just informational)
    if [[ -n "$LANGFUSE_PUBLIC_KEY" ]] && [[ -n "$LANGFUSE_SECRET_KEY" ]]; then
        log_success "Langfuse AI observability is configured"
    else
        log_info "Langfuse not configured (optional) - AI observability will be disabled"
    fi
    
    if [[ -n "$SENTRY_DSN" ]]; then
        log_success "Sentry error tracking is configured"
    else
        log_info "Sentry not configured (optional) - error tracking will be disabled"
    fi
    
    if [[ -n "$RESEND_API_KEY" ]]; then
        log_success "Resend email service is configured"
    else
        log_info "Resend not configured (optional) - email notifications will be disabled"
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Environment validation failed with $errors errors"
        log_info "Please add your GOOGLE_API_KEY to the .env file"
        exit 1
    fi
    
    log_success "Environment validation passed - ready to deploy! 🚀"
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
    log_header "Setting Up Trigger.dev (Local Development Mode)"
    
    cd "$JOBS_DIR"
    
    # For local development, we use a simplified approach
    log_step "Starting Trigger.dev in local development mode..."
    log_info "Using auto-configured development settings (no external signup required)"
    
    # Start trigger dev in background for local development
    pnpm exec trigger dev &
    TRIGGER_PID=$!
    
    # Wait a moment for trigger dev to start
    sleep 5
    
    cd - > /dev/null
    log_success "Trigger.dev local development mode started"
    log_info "Background jobs will run locally without external dependencies"
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
    echo "  4. Watch the PMAgent workflow execute with Gemini 2.5 Pro!"
    echo ""
    echo "🤖 AI Model Information:"
    echo "  • Model: Gemini 2.5 Pro (latest and most advanced)"
    echo "  • Context Window: Up to 1 million tokens"
    echo "  • Capabilities: Advanced reasoning, code generation, multimodal"
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
    echo "This script will set up and launch the complete Liam system with Gemini 2.5 Pro integration"
    echo ""
    echo -e "${GREEN}🎯 What this script does:${NC}"
    echo "  1. ✅ Prompts for your Google API key (only manual input required)"
    echo "  2. ⚙️  Auto-configures all other environment variables"
    echo "  3. 🐳 Sets up Supabase local database"
    echo "  4. 🔧 Configures Trigger.dev for background jobs"
    echo "  5. 🚀 Launches the frontend application"
    echo ""
    echo -e "${BLUE}📝 You'll need: A Google API key from https://makersuite.google.com/app/apikey${NC}"
    echo -e "${YELLOW}⏱️  Total setup time: ~4-5 minutes${NC}"
    echo ""
    
    # Check if we should skip confirmation in CI/automated environments
    if [[ "${CI:-false}" != "true" ]] && [[ "${SKIP_CONFIRMATION:-false}" != "true" ]]; then
        read -p "Ready to start? (y/N): " -n 1 -r
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
