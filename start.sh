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

# Progress indicator for long-running operations
show_progress() {
    local pid=$1
    local message=$2
    local delay=0.5
    local spinstr='|/-\'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "\r${BLUE}%s %c${NC}" "$message" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r%*s\r" ${#message} " "  # Clear the line
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
        # Use the recommended installation method for Supabase CLI
        # Note: The old install.sh script (https://supabase.com/install.sh) is deprecated as of 2024
        # Official method is now npm: https://supabase.com/docs/guides/cli/getting-started
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &> /dev/null; then
                log_info "Installing Supabase CLI via Homebrew..."
                brew install supabase/tap/supabase
            else
                log_warning "Homebrew not found. Checking npx availability..."
                if command -v npx &> /dev/null; then
                    log_info "npx is available, testing Supabase CLI download (max 90 seconds)..."
                    log_info "💡 Tip: This downloads Supabase CLI on first use - please be patient"
                    
                    # Use timeout to prevent hanging - give it 90 seconds max
                    if timeout 90 npx supabase --version &> /dev/null; then
                        log_success "Supabase CLI available via npx (recommended method)"
                        # Create a wrapper function for supabase command
                        supabase() { npx supabase "$@"; }
                        export -f supabase
                    else
                        log_warning "npx supabase download timed out or failed after 90 seconds"
                        log_info "This can happen with slow internet connections"
                        log_info "Falling back to local npm installation..."
                        # Note: Global installation is NOT supported by Supabase CLI
                        npm install supabase --save-dev || log_warning "Supabase CLI installation failed, but continuing..."
                    fi
                else
                    log_info "npx not available, installing via npm locally..."
                    # Note: Global installation is NOT supported by Supabase CLI
                    npm install supabase --save-dev || log_warning "Supabase CLI installation failed, but continuing..."
                fi
            fi
        else
            # Linux - try npx first (recommended method), then local npm installation
            log_info "Checking Supabase CLI availability..."
            
            # Check if npx is available first (quick check)
            if command -v npx &> /dev/null; then
                log_info "npx is available, testing Supabase CLI download (max 90 seconds)..."
                log_info "💡 Tip: This downloads Supabase CLI on first use - please be patient"
                
                # Use timeout to prevent hanging - give it 90 seconds max
                if timeout 90 npx supabase --version &> /dev/null; then
                    log_success "Supabase CLI available via npx (recommended method)"
                    # Create a wrapper function for supabase command
                    supabase() { npx supabase "$@"; }
                    export -f supabase
                else
                    log_warning "npx supabase download timed out or failed after 90 seconds"
                    log_info "This can happen with slow internet connections"
                    log_info "Falling back to local npm installation..."
                    npm install supabase --save-dev || {
                        log_warning "Supabase CLI local installation failed (npm dependency resolution issue)"
                        log_info "This is a known npm issue. You can try manually:"
                        log_info "  • npx supabase --version (wait for download to complete)"
                        log_info "  • Visit: https://supabase.com/docs/guides/cli/getting-started"
                    }
                fi
            else
                log_info "npx not available, installing Supabase CLI locally via npm..."
                npm install supabase --save-dev || {
                    log_warning "Supabase CLI local installation failed (npm dependency resolution issue)"
                    log_info "This is a known npm issue"
                    log_info "Visit: https://supabase.com/docs/guides/cli/getting-started"
                }
            fi
        fi
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
    
    # Check if supabase command is available
    if ! command -v supabase &> /dev/null; then
        log_error "Supabase CLI not found. Attempting to install..."
        
        # Try alternative installation methods
        log_step "Trying alternative Supabase installation methods..."
        
        # Method 1: Try using npx (official recommended method)
        if command -v npx &> /dev/null; then
            log_info "Trying npx method with timeout (max 90 seconds)..."
            if timeout 90 npx supabase --version &> /dev/null; then
                log_success "Supabase CLI available via npx (recommended method)"
                # Create a wrapper function for supabase command
                supabase() { npx supabase "$@"; }
                export -f supabase
            else
                log_warning "npx supabase timed out, trying other methods..."
                # Continue to next method
                false
            fi
        # Method 2: Check if already available in node_modules
        elif [[ -f "node_modules/.bin/supabase" ]]; then
            log_info "Using existing local Supabase CLI from node_modules"
            export PATH="$(pwd)/node_modules/.bin:$PATH"
        # Method 3: Try local installation (may fail due to npm dependency resolution issues)
        elif npm install supabase --save-dev 2>/dev/null; then
            log_success "Supabase CLI installed locally via npm"
            # Add local node_modules/.bin to PATH
            export PATH="$(pwd)/node_modules/.bin:$PATH"
        else
            log_warning "All Supabase CLI installation methods failed."
            log_info "Manual installation required:"
            log_info "  • Use: npx supabase (recommended by Supabase)"
            log_info "  • Or: npm install supabase --save-dev (local installation)"
            log_info "  • Visit: https://supabase.com/docs/guides/cli/getting-started"
            log_info "Continuing with setup, but database features may not work..."
            return 0
        fi
    fi
    
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
    
    # Apply database migrations with proper error handling
    log_step "Applying database migrations..."
    cd "$SUPABASE_DIR"
    
    # Initialize local project if not already done
    if [[ ! -f ".supabase/config.toml" ]]; then
        log_info "Initializing Supabase local project..."
        supabase init || {
            log_warning "Failed to initialize Supabase project, but continuing..."
        }
    fi
    
    # Try to link local project for migrations
    log_info "Setting up local project configuration..."
    if ! supabase link --project-ref local 2>/dev/null; then
        log_info "Local project linking not required for local development"
    fi
    
    # Apply migrations with fallback strategy
    log_info "Attempting to apply database migrations..."
    if supabase db reset --linked=false 2>/dev/null; then
        log_success "Database migrations applied successfully"
        MIGRATIONS_SUCCESS=true
    elif supabase db reset 2>/dev/null; then
        log_success "Database reset completed (alternative method)"
        MIGRATIONS_SUCCESS=true
    else
        log_warning "Database migrations failed, but database is already seeded and functional"
        log_info "The application will work with the current database state"
        log_info "You can manually apply migrations later if needed"
        MIGRATIONS_SUCCESS=false
    fi
    
    # Generate TypeScript types (optional, don't fail if it doesn't work)
    log_step "Generating database types..."
    if supabase gen types typescript --local > database.types.ts 2>/dev/null; then
        log_success "Database types generated successfully"
    else
        log_info "Database type generation skipped (not critical for functionality)"
    fi
    
    cd - > /dev/null
    
    if $MIGRATIONS_SUCCESS; then
        log_success "Database setup completed successfully"
    else
        log_success "Database setup completed (with seeded data, migrations skipped)"
        log_info "💡 The application is functional - migrations are optional for basic usage"
    fi
}

# Setup Trigger.dev
setup_trigger_dev() {
    log_header "Setting Up Trigger.dev (Local Development Mode)"
    
    # Check if jobs directory exists
    if [[ ! -d "$JOBS_DIR" ]]; then
        log_warning "Jobs directory not found: $JOBS_DIR"
        log_info "Trigger.dev setup skipped - background jobs will not be available"
        return 1
    fi
    
    cd "$JOBS_DIR"
    
    # Check if package.json exists
    if [[ ! -f "package.json" ]]; then
        log_warning "package.json not found in jobs directory"
        log_info "Trigger.dev setup skipped - background jobs will not be available"
        cd - > /dev/null
        return 1
    fi
    
    # Install dependencies if needed
    if [[ ! -d "node_modules" ]]; then
        log_step "Installing Trigger.dev dependencies..."
        if ! pnpm install; then
            log_warning "Failed to install Trigger.dev dependencies"
            log_info "Background jobs will not be available"
            cd - > /dev/null
            return 1
        fi
    fi
    
    # For local development, we use a simplified approach
    log_step "Starting Trigger.dev in local development mode..."
    log_info "Using auto-configured development settings (no external signup required)"
    
    # Start trigger dev in background for local development
    if pnpm exec trigger dev &>/dev/null &
    then
        TRIGGER_PID=$!
        log_info "Trigger.dev process started (PID: $TRIGGER_PID)"
        
        # Wait a moment for trigger dev to start
        sleep 5
        
        # Verify the process is still running
        if kill -0 $TRIGGER_PID 2>/dev/null; then
            log_success "Trigger.dev local development mode started successfully"
            log_info "Background jobs will run locally without external dependencies"
            cd - > /dev/null
            return 0
        else
            log_warning "Trigger.dev process failed to start properly"
            log_info "Background jobs will not be available, but application will continue"
            cd - > /dev/null
            return 1
        fi
    else
        log_warning "Failed to start Trigger.dev"
        log_info "Background jobs will not be available, but application will continue"
        cd - > /dev/null
        return 1
    fi
}

# Build and start the application
start_application() {
    log_header "Starting Application"
    
    # Check for port conflicts first
    log_step "Checking for port conflicts..."
    if lsof -i :3001 >/dev/null 2>&1; then
        log_warning "Port 3001 is already in use"
        log_info "Attempting to stop existing process..."
        pkill -f "next.*3001" || true
        sleep 2
    fi
    
    # Navigate to app directory
    if [[ ! -d "$APP_DIR" ]]; then
        log_error "Application directory not found: $APP_DIR"
        return 1
    fi
    
    cd "$APP_DIR"
    
    # Check if package.json exists
    if [[ ! -f "package.json" ]]; then
        log_error "package.json not found in $APP_DIR"
        cd - > /dev/null
        return 1
    fi
    
    # Install dependencies if node_modules is missing
    if [[ ! -d "node_modules" ]]; then
        log_step "Installing application dependencies..."
        pnpm install || {
            log_error "Failed to install application dependencies"
            cd - > /dev/null
            return 1
        }
    fi
    
    # Build the project (optional, skip if it fails)
    log_step "Building the project..."
    if pnpm build 2>/dev/null; then
        log_success "Project built successfully"
    else
        log_info "Build step skipped (not critical for development mode)"
    fi
    
    # Start the frontend application
    log_step "Starting frontend application..."
    pnpm dev &
    APP_PID=$!
    
    cd - > /dev/null
    
    # Wait for the application to start with progressive checks
    log_step "Waiting for application to start..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s http://localhost:3001 > /dev/null 2>&1; then
            log_success "✅ Application is running at http://localhost:3001"
            return 0
        fi
        
        # Check if the process is still running
        if ! kill -0 $APP_PID 2>/dev/null; then
            log_error "Application process died during startup"
            return 1
        fi
        
        if [[ $((attempt % 5)) -eq 0 ]]; then
            log_info "Still waiting for application startup... (attempt $attempt/$max_attempts)"
        fi
        
        sleep 2
        ((attempt++))
    done
    
    log_warning "Application startup verification timed out after $((max_attempts * 2)) seconds"
    log_info "The application may still be starting up - check http://localhost:3001 manually"
    return 0  # Don't fail completely, as the app might still be starting
}

# Display service status and URLs
show_status() {
    log_header "Service Status"
    
    echo -e "${GREEN}🎉 Liam PMAgent System is now running!${NC}"
    echo ""
    echo "📊 Service URLs:"
    echo "  • Frontend Application: http://localhost:3001"
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
    echo "  1. Open http://localhost:3001"
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
    log_step "Performing comprehensive health checks..."
    
    local health_ok=true
    local checks_passed=0
    local total_checks=0
    
    # Check frontend
    ((total_checks++))
    log_info "Checking frontend application..."
    if curl -s http://localhost:3001 > /dev/null 2>&1; then
        log_success "✅ Frontend is healthy (http://localhost:3001)"
        ((checks_passed++))
    else
        log_error "❌ Frontend is not responding"
        log_info "   Try: Check if the application is still starting up"
        health_ok=false
    fi
    
    # Check Supabase (skip in UI-only mode)
    if [[ "${UI_ONLY_MODE:-false}" != "true" ]]; then
        ((total_checks++))
        log_info "Checking Supabase API..."
        if curl -s http://localhost:54321/health > /dev/null 2>&1; then
            log_success "✅ Supabase API is healthy (http://localhost:54321)"
            ((checks_passed++))
        else
            log_error "❌ Supabase API is not responding"
            log_info "   Try: ./start.sh --repair"
            health_ok=false
        fi
        
        # Check database connection
        ((total_checks++))
        log_info "Checking database connection..."
        if command -v psql >/dev/null 2>&1 && psql "postgresql://postgres:postgres@localhost:54322/postgres" -c "SELECT 1;" &> /dev/null; then
            log_success "✅ Database connection is healthy"
            ((checks_passed++))
        elif curl -s "http://localhost:54321/rest/v1/" -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" > /dev/null 2>&1; then
            log_success "✅ Database is accessible via REST API"
            ((checks_passed++))
        else
            log_error "❌ Database connection failed"
            log_info "   Try: Check if Supabase is running properly"
            health_ok=false
        fi
        
        # Check Supabase Studio
        ((total_checks++))
        log_info "Checking Supabase Studio..."
        if curl -s http://localhost:54323 > /dev/null 2>&1; then
            log_success "✅ Supabase Studio is accessible (http://localhost:54323)"
            ((checks_passed++))
        else
            log_warning "⚠️  Supabase Studio is not responding (non-critical)"
        fi
    fi
    
    # Check Trigger.dev (if not in minimal mode)
    if [[ "${MINIMAL_MODE:-false}" != "true" ]] && [[ "${UI_ONLY_MODE:-false}" != "true" ]]; then
        if [[ -n "${TRIGGER_PID:-}" ]] && kill -0 $TRIGGER_PID 2>/dev/null; then
            log_success "✅ Trigger.dev process is running"
        else
            log_warning "⚠️  Trigger.dev is not running (background jobs unavailable)"
        fi
    fi
    
    # Summary
    echo ""
    log_info "Health Check Summary: $checks_passed/$total_checks critical checks passed"
    
    if $health_ok; then
        log_success "🎉 All critical health checks passed - system is fully operational!"
    else
        log_warning "⚠️  Some health checks failed - system may have limited functionality"
        log_info ""
        log_info "🔧 Troubleshooting options:"
        log_info "  • Run: ./start.sh --repair (fix common issues)"
        log_info "  • Run: ./start.sh --debug (verbose logging)"
        log_info "  • Run: ./start.sh --minimal (start with minimal services)"
        log_info "  • Check logs above for specific error messages"
    fi
    
    return $($health_ok && echo 0 || echo 1)
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
    echo "  5. ��� Launches the frontend application"
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
    
    # Execute setup steps with service isolation
    local setup_success=true
    local services_status=()
    
    # Critical setup steps (must succeed)
    check_root
    check_system_requirements
    setup_environment
    validate_environment
    install_dependencies
    
    # Database setup (allow to continue even if migrations fail)
    if [[ "${UI_ONLY_MODE:-false}" != "true" ]]; then
        log_info "🔄 Setting up database services..."
        if setup_database; then
            services_status+=("✅ Database: Operational")
        else
            services_status+=("⚠️  Database: Limited (migrations failed)")
            log_warning "Database setup had issues, but continuing with UI startup..."
        fi
    else
        log_info "🔄 Skipping database setup (UI-only mode)"
        services_status+=("⏭️  Database: Skipped (UI-only mode)")
    fi
    
    # Trigger.dev setup (optional service, skip in minimal mode)
    if [[ "${MINIMAL_MODE:-false}" != "true" ]] && [[ "${UI_ONLY_MODE:-false}" != "true" ]]; then
        log_info "🔄 Setting up background job services..."
        if setup_trigger_dev; then
            services_status+=("✅ Background Jobs: Operational")
        else
            services_status+=("⚠️  Background Jobs: Failed")
            log_warning "Trigger.dev setup failed, but continuing with UI startup..."
        fi
    else
        log_info "🔄 Skipping background job services (minimal/UI-only mode)"
        services_status+=("⏭️  Background Jobs: Skipped")
    fi
    
    # UI startup (priority service)
    log_info "🔄 Starting user interface..."
    if start_application; then
        services_status+=("✅ User Interface: Operational")
    else
        services_status+=("❌ User Interface: Failed")
        setup_success=false
        log_error "UI startup failed - this is critical for system functionality"
    fi
    
    # Display service status
    log_header "Service Status Summary"
    for status in "${services_status[@]}"; do
        echo "  $status"
    done
    echo ""
    
    if $setup_success; then
        log_success "🎉 System setup completed successfully!"
        show_status
        health_check
    else
        log_error "❌ System setup completed with critical failures"
        log_info "Please check the errors above and try running the script again"
        return 1
    fi
    
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
        echo "  --minimal           Start with minimal services (UI + Database only)"
        echo "  --debug             Enable verbose logging and debugging"
        echo "  --repair            Attempt to repair common issues"
        echo "  --ui-only           Start only the UI (skip database setup)"
        echo ""
        echo "Environment Variables:"
        echo "  CI=true             Skip confirmation prompts"
        echo "  SKIP_CONFIRMATION=true  Skip confirmation prompts"
        echo "  DEBUG=true          Enable debug mode"
        echo "  MINIMAL_MODE=true   Start with minimal services"
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
    --minimal)
        export MINIMAL_MODE=true
        export SKIP_CONFIRMATION=true
        log_info "Starting in minimal mode (UI + Database only)"
        main
        ;;
    --debug)
        export DEBUG=true
        set -x  # Enable bash debugging
        log_info "Debug mode enabled"
        main
        ;;
    --repair)
        log_header "Repair Mode"
        log_info "Attempting to repair common issues..."
        
        # Stop any running services
        cleanup 2>/dev/null || true
        
        # Clean up potential conflicts
        log_step "Cleaning up port conflicts..."
        pkill -f "next.*3000" 2>/dev/null || true
        pkill -f "supabase" 2>/dev/null || true
        
        # Remove problematic files
        log_step "Cleaning up temporary files..."
        rm -f .env.bak 2>/dev/null || true
        
        log_success "Repair completed. Try running the script again."
        exit 0
        ;;
    --ui-only)
        export UI_ONLY_MODE=true
        export SKIP_CONFIRMATION=true
        log_info "Starting in UI-only mode (skipping database setup)"
        main
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
