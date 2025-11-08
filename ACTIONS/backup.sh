#!/usr/bin/env bash

################################################################################
# Liam Database Backup Script
#
# This script creates automated backups of the PostgreSQL database.
# Supports both local and cloud storage destinations.
#
# Usage:
#   ./backup.sh [OPTIONS]
#
# Options:
#   --output DIR       Output directory for backups (default: ./backups)
#   --retention DAYS   Number of days to retain backups (default: 30)
#   --compress         Compress backup files with gzip
#   --s3-bucket NAME   Upload to S3 bucket (requires AWS CLI)
#   --encrypt          Encrypt backup with GPG
#   --help             Show this help message
#
# Examples:
#   ./backup.sh                                    # Basic backup
#   ./backup.sh --output /mnt/backups              # Custom location
#   ./backup.sh --compress --retention 7           # Compressed, 7-day retention
#   ./backup.sh --s3-bucket my-backups --encrypt   # S3 + encryption
#
# Requires:
#   - PostgreSQL client (psql, pg_dump)
#   - POSTGRES_URL environment variable
#   - AWS CLI (for S3 uploads)
#   - GPG (for encryption)
#
################################################################################

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default settings
OUTPUT_DIR="$PROJECT_ROOT/backups"
RETENTION_DAYS=30
COMPRESS=false
S3_BUCKET=""
ENCRYPT=false

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

################################################################################
# Parse Arguments
################################################################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            --compress)
                COMPRESS=true
                shift
                ;;
            --s3-bucket)
                S3_BUCKET="$2"
                shift 2
                ;;
            --encrypt)
                ENCRYPT=true
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
    
    # Check PostgreSQL tools
    if ! check_command pg_dump; then
        log_error "pg_dump not found"
        log_info "Install: sudo apt-get install postgresql-client"
        exit 1
    fi
    log_success "PostgreSQL client tools found"
    
    # Check for POSTGRES_URL
    if [ ! -f "$PROJECT_ROOT/.env.local" ]; then
        log_error ".env.local not found"
        log_info "Run: ./ACTIONS/setup.sh"
        exit 1
    fi
    
    # Load environment
    set -a
    source "$PROJECT_ROOT/.env.local"
    set +a
    
    if [ -z "${POSTGRES_URL:-}" ]; then
        log_error "POSTGRES_URL not configured in .env.local"
        exit 1
    fi
    log_success "Database connection configured"
    
    # Check optional tools
    if [ "$COMPRESS" = true ] && ! check_command gzip; then
        log_warning "gzip not found, compression disabled"
        COMPRESS=false
    fi
    
    if [ -n "$S3_BUCKET" ] && ! check_command aws; then
        log_error "AWS CLI not found, but S3 upload requested"
        log_info "Install: pip install awscli"
        exit 1
    fi
    
    if [ "$ENCRYPT" = true ] && ! check_command gpg; then
        log_error "GPG not found, but encryption requested"
        log_info "Install: sudo apt-get install gnupg"
        exit 1
    fi
}

################################################################################
# Backup Execution
################################################################################

create_backup() {
    log_section "Creating Backup"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Generate filename
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_name="liam_backup_${timestamp}"
    local backup_file="$OUTPUT_DIR/${backup_name}.sql"
    
    log_info "Backing up database..."
    log_info "Destination: $backup_file"
    
    # Create backup
    if pg_dump "$POSTGRES_URL" --no-owner --no-acl --clean --if-exists > "$backup_file"; then
        log_success "Database backup created"
    else
        log_error "Backup failed"
        exit 1
    fi
    
    # Get file size
    local size
    size=$(du -h "$backup_file" | cut -f1)
    log_info "Backup size: $size"
    
    # Compress if requested
    if [ "$COMPRESS" = true ]; then
        log_info "Compressing backup..."
        gzip "$backup_file"
        backup_file="${backup_file}.gz"
        local compressed_size
        compressed_size=$(du -h "$backup_file" | cut -f1)
        log_success "Compressed to: $compressed_size"
    fi
    
    # Encrypt if requested
    if [ "$ENCRYPT" = true ]; then
        log_info "Encrypting backup..."
        gpg --symmetric --cipher-algo AES256 "$backup_file"
        rm "$backup_file"
        backup_file="${backup_file}.gpg"
        log_success "Backup encrypted"
    fi
    
    # Upload to S3 if requested
    if [ -n "$S3_BUCKET" ]; then
        log_info "Uploading to S3..."
        local s3_path="s3://${S3_BUCKET}/liam-backups/$(basename "$backup_file")"
        
        if aws s3 cp "$backup_file" "$s3_path"; then
            log_success "Uploaded to: $s3_path"
        else
            log_error "S3 upload failed"
        fi
    fi
    
    echo ""
    log_success "Backup complete: $backup_file"
}

################################################################################
# Cleanup Old Backups
################################################################################

cleanup_old_backups() {
    log_section "Cleanup Old Backups"
    
    log_info "Removing backups older than $RETENTION_DAYS days..."
    
    # Find and remove old backups
    local old_backups
    old_backups=$(find "$OUTPUT_DIR" -name "liam_backup_*.sql*" -mtime +$RETENTION_DAYS 2>/dev/null || true)
    
    if [ -z "$old_backups" ]; then
        log_info "No old backups to remove"
    else
        local count=0
        while IFS= read -r file; do
            rm -f "$file"
            count=$((count + 1))
        done <<< "$old_backups"
        log_success "Removed $count old backup(s)"
    fi
}

################################################################################
# Backup Verification
################################################################################

verify_backup() {
    local backup_file=$1
    
    log_section "Backup Verification"
    
    log_info "Verifying backup integrity..."
    
    # Check file exists and is not empty
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found"
        return 1
    fi
    
    if [ ! -s "$backup_file" ]; then
        log_error "Backup file is empty"
        return 1
    fi
    
    # Check file is readable
    if [ ! -r "$backup_file" ]; then
        log_error "Backup file is not readable"
        return 1
    fi
    
    # For SQL files, check for common markers
    if [[ "$backup_file" == *.sql ]]; then
        if grep -q "PostgreSQL database dump" "$backup_file" 2>/dev/null; then
            log_success "Backup verification passed"
            return 0
        else
            log_warning "Backup file may be corrupted (missing PostgreSQL marker)"
            return 1
        fi
    fi
    
    log_success "Backup file exists and is readable"
    return 0
}

################################################################################
# Display Summary
################################################################################

display_summary() {
    log_section "Backup Summary"
    
    local total_backups
    total_backups=$(find "$OUTPUT_DIR" -name "liam_backup_*.sql*" 2>/dev/null | wc -l)
    
    local total_size
    total_size=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
    
    cat <<EOF
$(echo -e "${GREEN}")
╔═══════════════════════════════════════════════════════════════╗
║                    BACKUP COMPLETE                             ║
╚═══════════════════════════════════════════════════════════════╝
$(echo -e "${NC}")

$(echo -e "${BLUE}📊 Statistics:${NC}")
  Total Backups: $total_backups
  Total Size: $total_size
  Retention: $RETENTION_DAYS days
  Location: $OUTPUT_DIR

$(echo -e "${BLUE}📝 Next Steps:${NC}")
  View backups: ls -lh $OUTPUT_DIR
  Test restore: ./ACTIONS/restore.sh --file <backup-file>
  Schedule: Add to cron or GitHub Actions

$(echo -e "${BLUE}🔒 Security Tips:${NC}")
  - Use --encrypt for sensitive data
  - Store backups off-site (--s3-bucket)
  - Test restore regularly
  - Restrict backup file permissions

$(echo -e "${GREEN}Backup successful! ✅${NC}")

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
$(echo -e "${BLUE}")
╔═══════════════════════════════════════════════════════════════╗
║                    LIAM BACKUP SCRIPT                          ║
║                   Database Backup & Archive                    ║
╚═══════════════════════════════════════════════════════════════╝
$(echo -e "${NC}")

EOF
    
    # Run backup steps
    check_prerequisites
    create_backup
    
    # Verify the backup
    local latest_backup
    latest_backup=$(find "$OUTPUT_DIR" -name "liam_backup_*.sql*" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [ -n "$latest_backup" ]; then
        verify_backup "$latest_backup"
    fi
    
    cleanup_old_backups
    display_summary
    
    log_success "Backup completed successfully"
}

# Run main function
main "$@"

