#!/usr/bin/env bash

################################################################################
# Liam Database Restore Script
#
# This script restores a PostgreSQL database from a backup file.
# Supports compressed and encrypted backups.
#
# Usage:
#   ./restore.sh --file <backup-file> [OPTIONS]
#
# Options:
#   --file FILE        Backup file to restore (required)
#   --target-db URL    Target database URL (default: from .env.local)
#   --decrypt          Decrypt backup before restore
#   --dry-run          Validate backup without restoring
#   --force            Skip confirmation prompt
#   --help             Show this help message
#
# Examples:
#   ./restore.sh --file backups/liam_backup_20250108.sql
#   ./restore.sh --file backup.sql.gz --decrypt
#   ./restore.sh --file backup.sql --dry-run
#
# ⚠️  WARNING: This will REPLACE all data in the target database!
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

# Settings
BACKUP_FILE=""
TARGET_DB=""
DECRYPT=false
DRY_RUN=false
FORCE=false

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
            --file)
                BACKUP_FILE="$2"
                shift 2
                ;;
            --target-db)
                TARGET_DB="$2"
                shift 2
                ;;
            --decrypt)
                DECRYPT=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
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
    
    # Validate required arguments
    if [ -z "$BACKUP_FILE" ]; then
        log_error "Backup file is required (--file)"
        exit 1
    fi
}

################################################################################
# Prerequisites Check
################################################################################

check_prerequisites() {
    log_section "Prerequisites Check"
    
    # Check PostgreSQL tools
    if ! check_command psql; then
        log_error "psql not found"
        log_info "Install: sudo apt-get install postgresql-client"
        exit 1
    fi
    log_success "PostgreSQL client tools found"
    
    # Check backup file exists
    if [ ! -f "$BACKUP_FILE" ]; then
        log_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    log_success "Backup file found: $BACKUP_FILE"
    
    # Load environment if target DB not specified
    if [ -z "$TARGET_DB" ]; then
        if [ ! -f "$PROJECT_ROOT/.env.local" ]; then
            log_error ".env.local not found"
            exit 1
        fi
        
        set -a
        source "$PROJECT_ROOT/.env.local"
        set +a
        
        if [ -z "${POSTGRES_URL:-}" ]; then
            log_error "POSTGRES_URL not configured"
            exit 1
        fi
        
        TARGET_DB="$POSTGRES_URL"
    fi
    log_success "Target database configured"
    
    # Check decryption if needed
    if [ "$DECRYPT" = true ] && ! check_command gpg; then
        log_error "GPG not found but --decrypt specified"
        exit 1
    fi
}

################################################################################
# Backup Validation
################################################################################

validate_backup() {
    log_section "Backup Validation"
    
    local file_to_check="$BACKUP_FILE"
    
    # Handle encrypted files
    if [[ "$BACKUP_FILE" == *.gpg ]]; then
        if [ "$DECRYPT" = false ]; then
            log_error "Backup is encrypted but --decrypt not specified"
            exit 1
        fi
        log_info "Backup is encrypted, will decrypt during restore"
    fi
    
    # Handle compressed files
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        log_info "Backup is compressed, will decompress during restore"
        
        # Quick gzip test
        if ! gzip -t "$BACKUP_FILE" 2>/dev/null; then
            log_error "Backup file appears to be corrupted (gzip test failed)"
            exit 1
        fi
        log_success "Compression integrity verified"
    fi
    
    # Check file size
    local size
    size=$(du -h "$BACKUP_FILE" | cut -f1)
    log_info "Backup file size: $size"
    
    log_success "Backup validation passed"
}

################################################################################
# Confirmation
################################################################################

confirm_restore() {
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    log_section "⚠️  Restore Confirmation"
    
    echo -e "${YELLOW}"
    cat <<EOF
╔═══════════════════════════════════════════════════════════════╗
║                         ⚠️  WARNING ⚠️                        ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  This operation will REPLACE ALL DATA in the target database  ║
║                                                               ║
║  Backup file: $(basename "$BACKUP_FILE")
║  Target: $(echo "$TARGET_DB" | sed 's/:[^:]*@/:****@/')
║                                                               ║
║  This action CANNOT be undone!                               ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Restore cancelled by user"
        exit 0
    fi
    
    log_success "User confirmed restore"
}

################################################################################
# Restore Execution
################################################################################

perform_restore() {
    log_section "Performing Restore"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN MODE - No actual restore will be performed"
        return 0
    fi
    
    local restore_file="$BACKUP_FILE"
    local temp_file=""
    
    # Decrypt if needed
    if [[ "$BACKUP_FILE" == *.gpg ]]; then
        log_info "Decrypting backup..."
        temp_file=$(mktemp)
        if gpg --decrypt "$BACKUP_FILE" > "$temp_file" 2>/dev/null; then
            restore_file="$temp_file"
            log_success "Backup decrypted"
        else
            log_error "Decryption failed"
            rm -f "$temp_file"
            exit 1
        fi
    fi
    
    # Decompress if needed
    if [[ "$restore_file" == *.gz ]]; then
        log_info "Decompressing backup..."
        local decompressed=$(mktemp)
        if gunzip -c "$restore_file" > "$decompressed" 2>/dev/null; then
            [ -n "$temp_file" ] && rm -f "$temp_file"
            restore_file="$decompressed"
            temp_file="$decompressed"
            log_success "Backup decompressed"
        else
            log_error "Decompression failed"
            [ -n "$temp_file" ] && rm -f "$temp_file"
            exit 1
        fi
    fi
    
    # Restore database
    log_info "Restoring database..."
    log_warning "This may take several minutes..."
    
    if psql "$TARGET_DB" < "$restore_file" 2>&1 | tee /tmp/liam-restore.log; then
        log_success "Database restored successfully"
    else
        log_error "Restore failed"
        log_info "Check logs: /tmp/liam-restore.log"
        [ -n "$temp_file" ] && rm -f "$temp_file"
        exit 1
    fi
    
    # Cleanup temp file
    [ -n "$temp_file" ] && rm -f "$temp_file"
}

################################################################################
# Verification
################################################################################

verify_restore() {
    log_section "Verifying Restore"
    
    if [ "$DRY_RUN" = true ]; then
        log_success "Dry run completed successfully"
        return 0
    fi
    
    log_info "Checking database connectivity..."
    
    if psql "$TARGET_DB" -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "Database is accessible"
    else
        log_error "Database connection failed after restore"
        return 1
    fi
    
    log_info "Checking critical tables..."
    
    local tables=("projects" "building_schemas" "organizations")
    local missing=0
    
    for table in "${tables[@]}"; do
        if psql "$TARGET_DB" -c "\dt $table" 2>&1 | grep -q "$table"; then
            log_success "Table exists: $table"
        else
            log_warning "Table missing: $table"
            missing=$((missing + 1))
        fi
    done
    
    if [ $missing -eq 0 ]; then
        log_success "All critical tables present"
    else
        log_warning "$missing critical table(s) missing"
    fi
}

################################################################################
# Display Summary
################################################################################

display_summary() {
    log_section "Restore Summary"
    
    cat <<EOF
$(echo -e "${GREEN}")
╔═══════════════════════════════════════════════════════════════╗
║                    RESTORE COMPLETE                            ║
╚═══════════════════════════════════════════════════════════════╝
$(echo -e "${NC}")

$(echo -e "${BLUE}📊 Details:${NC}")
  Backup File: $(basename "$BACKUP_FILE")
  Status: $([ "$DRY_RUN" = true ] && echo "Dry Run" || echo "Restored")
  Time: $(date)

$(echo -e "${BLUE}📝 Next Steps:${NC}")
  1. Verify application functionality
  2. Check data integrity
  3. Run tests if applicable
  4. Monitor for any issues

$(echo -e "${BLUE}🔧 Useful Commands:${NC}")
  Check tables: psql "\$POSTGRES_URL" -c "\\dt"
  Check data: psql "\$POSTGRES_URL" -c "SELECT COUNT(*) FROM projects;"
  Check logs: tail -f .liam-app.log

$(echo -e "${GREEN}Restore $([ "$DRY_RUN" = true ] && echo "validated" || echo "completed") successfully! ✅${NC}")

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
║                    LIAM RESTORE SCRIPT                         ║
║                   Database Recovery Tool                       ║
╚═══════════════════════════════════════════════════════════════╝
$(echo -e "${NC}")

EOF
    
    # Run restore steps
    check_prerequisites
    validate_backup
    confirm_restore
    perform_restore
    verify_restore
    display_summary
    
    log_success "Restore process completed"
}

# Run main function
main "$@"

