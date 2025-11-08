#!/usr/bin/env bash

################################################################################
# Liam Setup Script
# 
# This script performs a complete setup of the Liam project including:
# - Environment detection and validation
# - System dependencies installation
# - Node.js and pnpm setup
# - Project dependencies installation
# - Environment configuration
# - Database setup validation
# - OAuth key generation
#
# Usage:
#   ./setup.sh [--skip-deps] [--skip-build]
#
# Options:
#   --skip-deps    Skip system dependency installation
#   --skip-build   Skip build step (use development mode)
#   --help         Show this help message
#
################################################################################

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly REQUIRED_NODE_VERSION="20"
readonly REQUIRED_PNPM_VERSION="10"

# Flags
SKIP_DEPS=false
SKIP_BUILD=false

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
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

version_compare() {
    local version1=$1
    local version2=$2
    
    if [ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -n1)" = "$version2" ]; then
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
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
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
# Environment Detection
################################################################################

detect_environment() {
    log_section "Environment Detection"
    
    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_info "Operating System: Linux"
        
        # Check if WSL
        if grep -qi microsoft /proc/version 2>/dev/null; then
            log_info "Environment: Windows Subsystem for Linux (WSL)"
            export IS_WSL=true
        else
            export IS_WSL=false
        fi
        
        # Detect distribution
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            log_info "Distribution: $NAME $VERSION"
            export OS_NAME="$ID"
            export OS_VERSION="$VERSION_ID"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        log_info "Operating System: macOS"
        export OS_NAME="macos"
    else
        log_warning "Unknown operating system: $OSTYPE"
        export OS_NAME="unknown"
    fi
    
    log_success "Environment detection complete"
}

################################################################################
# System Dependencies
################################################################################

install_system_dependencies() {
    if [ "$SKIP_DEPS" = true ]; then
        log_warning "Skipping system dependency installation (--skip-deps)"
        return 0
    fi
    
    log_section "System Dependencies"
    
    # Check if we need sudo
    local SUDO=""
    if [ "$EUID" -ne 0 ]; then
        if check_command sudo; then
            SUDO="sudo"
        else
            log_warning "Running without sudo - may encounter permission issues"
        fi
    fi
    
    case "$OS_NAME" in
        ubuntu|debian)
            log_info "Installing dependencies for Ubuntu/Debian..."
            $SUDO apt-get update -qq
            $SUDO apt-get install -y -qq \
                curl \
                ca-certificates \
                gnupg \
                build-essential \
                git \
                || log_warning "Some packages may have failed to install"
            ;;
        fedora|rhel|centos)
            log_info "Installing dependencies for Fedora/RHEL/CentOS..."
            $SUDO dnf install -y \
                curl \
                ca-certificates \
                gcc \
                gcc-c++ \
                make \
                git \
                || log_warning "Some packages may have failed to install"
            ;;
        macos)
            log_info "Checking Homebrew..."
            if ! check_command brew; then
                log_error "Homebrew not found. Please install from https://brew.sh/"
                exit 1
            fi
            log_info "Installing dependencies via Homebrew..."
            brew install curl git || log_warning "Some packages may have failed to install"
            ;;
        *)
            log_warning "Unknown OS - skipping system dependency installation"
            ;;
    esac
    
    log_success "System dependencies installed"
}

################################################################################
# Node.js Installation
################################################################################

install_nodejs() {
    log_section "Node.js Setup"
    
    # Check if Node.js is already installed
    if check_command node; then
        local current_version
        current_version=$(node -v | sed 's/v//' | cut -d. -f1)
        
        if version_compare "$current_version" "$REQUIRED_NODE_VERSION"; then
            log_success "Node.js v$current_version is already installed"
            return 0
        else
            log_warning "Node.js v$current_version found, but v$REQUIRED_NODE_VERSION+ required"
        fi
    fi
    
    log_info "Installing Node.js v${REQUIRED_NODE_VERSION}..."
    
    case "$OS_NAME" in
        ubuntu|debian)
            # Install Node.js via NodeSource
            if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
                log_info "Adding NodeSource repository..."
                curl -fsSL https://deb.nodesource.com/setup_${REQUIRED_NODE_VERSION}.x | sudo -E bash -
            fi
            sudo apt-get install -y nodejs
            ;;
        fedora|rhel|centos)
            log_info "Adding NodeSource repository..."
            curl -fsSL https://rpm.nodesource.com/setup_${REQUIRED_NODE_VERSION}.x | sudo bash -
            sudo dnf install -y nodejs
            ;;
        macos)
            log_info "Installing Node.js via Homebrew..."
            brew install node@${REQUIRED_NODE_VERSION}
            ;;
        *)
            log_error "Cannot auto-install Node.js on this OS"
            log_info "Please install Node.js v${REQUIRED_NODE_VERSION}+ from https://nodejs.org/"
            exit 1
            ;;
    esac
    
    # Verify installation
    if check_command node; then
        local version
        version=$(node -v)
        log_success "Node.js $version installed successfully"
    else
        log_error "Node.js installation failed"
        exit 1
    fi
}

################################################################################
# pnpm Installation
################################################################################

install_pnpm() {
    log_section "pnpm Setup"
    
    # Check if pnpm is already installed
    if check_command pnpm; then
        local current_version
        current_version=$(pnpm -v | cut -d. -f1)
        
        if version_compare "$current_version" "$REQUIRED_PNPM_VERSION"; then
            log_success "pnpm v$current_version is already installed"
            return 0
        else
            log_warning "pnpm v$current_version found, updating to v${REQUIRED_PNPM_VERSION}+"
        fi
    fi
    
    log_info "Installing pnpm..."
    
    # Install via npm (most reliable method)
    npm install -g pnpm@latest
    
    # Verify installation
    if check_command pnpm; then
        local version
        version=$(pnpm -v)
        log_success "pnpm v$version installed successfully"
    else
        log_error "pnpm installation failed"
        exit 1
    fi
}

################################################################################
# Environment Configuration
################################################################################

configure_environment() {
    log_section "Environment Configuration"
    
    cd "$PROJECT_ROOT"
    
    # Check if .env.local exists
    if [ -f .env.local ]; then
        log_info ".env.local already exists"
        
        # Validate required variables
        local missing_vars=()
        
        if ! grep -q "OPENAI_API_KEY=" .env.local || grep -q "OPENAI_API_KEY=\"\"" .env.local; then
            missing_vars+=("OPENAI_API_KEY")
        fi
        
        if ! grep -q "NEXT_PUBLIC_SUPABASE_URL=" .env.local || grep -q "NEXT_PUBLIC_SUPABASE_URL=\"\"" .env.local; then
            missing_vars+=("NEXT_PUBLIC_SUPABASE_URL")
        fi
        
        if ! grep -q "POSTGRES_URL=" .env.local || grep -q "POSTGRES_URL=\"\"" .env.local; then
            missing_vars+=("POSTGRES_URL")
        fi
        
        if [ ${#missing_vars[@]} -gt 0 ]; then
            log_warning "Missing or empty variables in .env.local:"
            for var in "${missing_vars[@]}"; do
                log_warning "  - $var"
            done
            log_info "Please configure these variables manually in .env.local"
        else
            log_success "All required environment variables are configured"
        fi
        
        # Check OAuth key
        if ! grep -q "LIAM_GITHUB_OAUTH_KEYRING=" .env.local || grep -q "LIAM_GITHUB_OAUTH_KEYRING=\"\"" .env.local; then
            log_info "Generating OAuth encryption key..."
            generate_oauth_key
        else
            log_success "OAuth encryption key already configured"
        fi
    else
        log_info "Creating .env.local from template..."
        
        if [ -f .env.template ]; then
            cp .env.template .env.local
            log_success ".env.local created"
            
            # Generate OAuth key
            generate_oauth_key
            
            log_warning "Please configure the following variables in .env.local:"
            log_warning "  - OPENAI_API_KEY (or OPENAI_BASE_URL for Z.AI)"
            log_warning "  - NEXT_PUBLIC_SUPABASE_URL"
            log_warning "  - NEXT_PUBLIC_SUPABASE_ANON_KEY"
            log_warning "  - POSTGRES_URL"
            log_warning "  - SUPABASE_SERVICE_ROLE_KEY"
        else
            log_error ".env.template not found"
            exit 1
        fi
    fi
    
    # Ensure .env file exists (for Turbo)
    if [ ! -f .env ]; then
        touch .env
        log_info "Created empty .env file"
    fi
}

generate_oauth_key() {
    if check_command node; then
        local oauth_key
        oauth_key=$(node -e "console.log('k2025-01:' + require('crypto').randomBytes(32).toString('base64'))")
        
        # Update .env.local
        if grep -q "LIAM_GITHUB_OAUTH_KEYRING=" .env.local; then
            sed -i "s|LIAM_GITHUB_OAUTH_KEYRING=.*|LIAM_GITHUB_OAUTH_KEYRING=\"$oauth_key\"|" .env.local
        else
            echo "LIAM_GITHUB_OAUTH_KEYRING=\"$oauth_key\"" >> .env.local
        fi
        
        log_success "OAuth encryption key generated"
    else
        log_warning "Node.js not available - cannot generate OAuth key"
    fi
}

################################################################################
# Project Dependencies
################################################################################

install_dependencies() {
    log_section "Project Dependencies"
    
    cd "$PROJECT_ROOT"
    
    log_info "Installing project dependencies..."
    log_info "This may take 3-5 minutes..."
    
    # Use frozen lockfile for reproducible builds
    if pnpm install --frozen-lockfile; then
        log_success "Dependencies installed successfully"
    else
        log_warning "Failed with --frozen-lockfile, trying without..."
        if pnpm install; then
            log_success "Dependencies installed successfully"
        else
            log_error "Failed to install dependencies"
            exit 1
        fi
    fi
    
    # Show package count
    local package_count
    package_count=$(find node_modules -maxdepth 1 -type d 2>/dev/null | wc -l)
    log_info "Installed $package_count packages"
}

################################################################################
# Build Project
################################################################################

build_project() {
    if [ "$SKIP_BUILD" = true ]; then
        log_warning "Skipping build step (--skip-build)"
        log_info "You can use development mode with: pnpm dev"
        return 0
    fi
    
    log_section "Building Project"
    
    cd "$PROJECT_ROOT"
    
    log_info "Building Liam..."
    log_warning "This may take 5-10 minutes on first build"
    log_info "Press Ctrl+C to skip build and use development mode"
    
    # Build with timeout (optional)
    if timeout 600 pnpm build --filter @liam-hq/app 2>&1 | tee /tmp/liam-build.log | tail -20; then
        log_success "Build completed successfully"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_warning "Build timed out after 10 minutes"
        else
            log_warning "Build encountered issues (exit code: $exit_code)"
        fi
        log_info "You can still use development mode with: pnpm dev"
    fi
}

################################################################################
# Database Validation
################################################################################

validate_database() {
    log_section "Database Validation"
    
    # Check if database URL is configured
    if [ -f "$PROJECT_ROOT/.env.local" ]; then
        if grep -q "POSTGRES_URL=" "$PROJECT_ROOT/.env.local" && \
           ! grep -q "POSTGRES_URL=\"\"" "$PROJECT_ROOT/.env.local"; then
            log_success "Database connection string configured"
            
            # Try to connect (optional)
            local db_url
            db_url=$(grep "POSTGRES_URL=" "$PROJECT_ROOT/.env.local" | cut -d= -f2- | tr -d '"')
            
            if [ -n "$db_url" ] && check_command psql; then
                log_info "Testing database connection..."
                if psql "$db_url" -c "SELECT 1;" &>/dev/null; then
                    log_success "Database connection successful"
                else
                    log_warning "Could not connect to database (may be normal if not running)"
                fi
            fi
        else
            log_warning "Database URL not configured in .env.local"
            log_info "Configure POSTGRES_URL for full functionality"
        fi
    fi
}

################################################################################
# Post-Setup Instructions
################################################################################

show_next_steps() {
    log_section "Setup Complete! 🎉"
    
    cat <<EOF
$(echo -e "${GREEN}")
╔═══════════════════════════════════════════════════════════════╗
║                    LIAM SETUP COMPLETE!                        ║
╚═══════════════════════════════════════════════════════════════╝
$(echo -e "${NC}")

$(echo -e "${BLUE}📦 What was installed:${NC}")
  ✅ Node.js $(node -v 2>/dev/null || echo "not found")
  ✅ pnpm v$(pnpm -v 2>/dev/null || echo "not found")
  ✅ Project dependencies (~2000 packages)
  ✅ Environment configuration

$(echo -e "${BLUE}🚀 Next Steps:${NC}")

$(echo -e "${GREEN}1. Configure Environment Variables${NC}")
   Edit: .env.local
   Required:
     - OPENAI_API_KEY (or OPENAI_BASE_URL for Z.AI)
     - NEXT_PUBLIC_SUPABASE_URL
     - POSTGRES_URL

$(echo -e "${GREEN}2. Start Development Server${NC}")
   cd $PROJECT_ROOT
   ./ACTIONS/start.sh

   Or use:
   pnpm dev

$(echo -e "${GREEN}3. Open in Browser${NC}")
   http://localhost:3001

$(echo -e "${GREEN}4. Test the Agent System${NC}")
   Type: "Create a blog system with users and posts"
   Watch the 4 AI agents work in real-time! 🤖

$(echo -e "${BLUE}📚 Documentation:${NC}")
  - Quick Start: ./ACTIONS/INSTRUCTIONS.md
  - Setup Guide: ./SETUP_COMPLETE.md
  - Full Manual: ./DEPLOYMENT_GUIDE.md

$(echo -e "${BLUE}🛠️  Available Commands:${NC}")
  ./ACTIONS/start.sh    - Start development server
  ./ACTIONS/stop.sh     - Stop all Liam processes
  pnpm dev              - Start all development servers
  pnpm build            - Build for production
  pnpm test             - Run tests

$(echo -e "${YELLOW}⚠️  Important Notes:${NC}")
  - Development mode doesn't require a build
  - First run may take longer (Next.js optimization)
  - Make sure to configure .env.local before starting

$(echo -e "${GREEN}Happy coding with Liam! 🎨✨${NC}")

EOF
}

################################################################################
# Main Execution
################################################################################

main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Print header
    cat <<EOF
$(echo -e "${BLUE}")
╔═══════════════════════════════════════════════════════════════╗
║                    LIAM SETUP SCRIPT                           ║
║                   AI Database Schema Designer                  ║
╚═══════════════════════════════════════════════════════════════╝
$(echo -e "${NC}")

EOF
    
    # Run setup steps
    detect_environment
    install_system_dependencies
    install_nodejs
    install_pnpm
    configure_environment
    install_dependencies
    validate_database
    build_project
    
    # Show next steps
    show_next_steps
    
    log_success "Setup complete!"
}

# Run main function
main "$@"

