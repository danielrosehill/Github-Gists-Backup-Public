#!/bin/bash
# Script to pull GitHub gists
# Based on the functional model in models/gist-backup.sh

# Configuration
GITHUB_USERNAME="randomuser123"
# Path to backup directory (change this to your preferred location)
BACKUP_PATH="./github-gists-backup"
GITHUB_TOKEN="github_pat_12ABCDEFG0HiJk1LmN2OPq3RsTuV4WxYz5AbCdEfGhIjKlMnOpQrStUvWxYz123456"
# Max length for folder name prefix (from file name)
MAX_NAME_LENGTH=30
# Current date in DDMMYY format for folder naming
CURRENT_DATE=$(date '+%d%m%y')

# Log function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Error log function
error_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Create backup directory
log "Starting GitHub gists backup to $BACKUP_PATH"
mkdir -p "$BACKUP_PATH/public" "$BACKUP_PATH/private" || {
  error_log "Failed to create backup directories"
  exit 1
}

# Log configuration
log "Configuration:"
log "- Username: $GITHUB_USERNAME"
log "- Backup Path: $BACKUP_PATH"
log "- GitHub Token: ${GITHUB_TOKEN:0:8}... (truncated)"

# Check for required dependencies
log "Checking for required dependencies..."
for cmd in curl jq git; do
  if ! command -v $cmd &> /dev/null; then
    error_log "$cmd is not installed."
    exit 1
  fi
done
log "All required dependencies are installed."

# Change to backup directory
cd "$BACKUP_PATH" || {
  error_log "Failed to change to backup directory"
  exit 1
}

log "Fetching Gists for user: $GITHUB_USERNAME..."

# Initialize counters
SUCCESSFUL=0
FAILED=0

# Fetch and process gists with pagination
page=1
while true; do
  log "Fetching page $page..."
  
  response=$(curl -s -u "$GITHUB_USERNAME:$GITHUB_TOKEN" \
    "https://api.github.com/users/$GITHUB_USERNAME/gists?page=$page&per_page=100")
  
  # Break if no more gists
  if [ -z "$(echo "$response" | jq -r '.[0]')" ]; then
    log "No more gists found on page $page"
    break
  fi
  
  # Process each gist
  echo "$response" | jq -c '.[]' | while read -r gist; do
    gist_id=$(echo "$gist" | jq -r '.id')
    is_public=$(echo "$gist" | jq -r '.public')
    git_url=$(echo "$gist" | jq -r '.git_pull_url')
    
    # Determine if public or private
    if [ "$is_public" = "true" ]; then
      visibility="public"
    else
      visibility="private"
    fi
    
    # Get the first filename from the gist
    filename=$(echo "$gist" | jq -r '.files | keys | .[0]')
    
    # Create a sanitized folder name from the filename (first MAX_NAME_LENGTH chars)
    # Remove special characters and spaces, replace with underscores
    sanitized_name=$(echo "${filename:0:$MAX_NAME_LENGTH}" | tr -c '[:alnum:]' '_' | tr -s '_')
    folder_name="${sanitized_name}_${CURRENT_DATE}"
    
    # Full path for this gist
    gist_path="$BACKUP_PATH/$visibility/$folder_name"
    
    # Check if we've already backed up this gist (using a marker file)
    existing_folder=""
    for dir in "$BACKUP_PATH/$visibility"/*; do
      if [ -f "$dir/.gist_id" ] && [ "$(cat "$dir/.gist_id")" = "$gist_id" ]; then
        existing_folder="$dir"
        break
      fi
    done
    
    if [ -n "$existing_folder" ]; then
      # Gist already exists, update it
      log "Updating gist in $existing_folder..."
      if git -C "$existing_folder" pull --quiet; then
        log "Successfully updated gist $gist_id in $existing_folder"
        ((SUCCESSFUL++))
      else
        error_log "Failed to update gist $gist_id in $existing_folder"
        ((FAILED++))
      fi
    else
      # New gist, clone it
      log "Cloning gist $gist_id to $gist_path..."
      if git clone --quiet "$git_url" "$gist_path"; then
        # Create a marker file with the gist ID for future incremental updates
        echo "$gist_id" > "$gist_path/.gist_id"
        log "Successfully cloned gist $gist_id to $gist_path"
        ((SUCCESSFUL++))
      else
        error_log "Failed to clone gist $gist_id to $gist_path"
        ((FAILED++))
      fi
    fi
  done
  
  page=$((page + 1))
done

# Print summary
log "=== Backup Summary ==="
log "Successful: $SUCCESSFUL"
log "Failed: $FAILED"
log "Backup location: $BACKUP_PATH"

# Log total disk usage
TOTAL_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
log "Total backup size: $TOTAL_SIZE"

# Log completion time
log "Backup completed at: $(date '+%Y-%m-%d %H:%M:%S')"

# Exit with error if any backups failed
if [ "$FAILED" -gt 0 ]; then
  error_log "Backup completed with $FAILED failures"
  exit 1
else
  log "✅ Gist backup complete: $BACKUP_PATH"
  exit 0
fi