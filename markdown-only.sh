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
# Directory for flat markdown files structure
MARKDOWN_DIR="$BACKUP_PATH/markdown_files"

# Log function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Error log function
error_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Function to extract markdown files from a gist folder and copy to flat structure
extract_markdown_files() {
  local gist_folder="$1"
  local gist_id="$2"
  
  log "Extracting markdown files from gist $gist_id..."
  
  # Find all markdown files in the gist folder
  find "$gist_folder" -type f -name "*.md" | while read -r md_file; do
    # Get the base filename
    base_filename=$(basename "$md_file")
    target_file="$MARKDOWN_DIR/$base_filename"
    
    # Handle filename conflicts by adding a number suffix
    if [ -f "$target_file" ]; then
      log "File $base_filename already exists in markdown directory"
      counter=1
      filename_without_ext="${base_filename%.md}"
      while [ -f "$MARKDOWN_DIR/${filename_without_ext}_${counter}.md" ]; do
        ((counter++))
      done
      target_file="$MARKDOWN_DIR/${filename_without_ext}_${counter}.md"
      log "Using alternative filename: $(basename "$target_file")"
    fi
    
    # Copy the markdown file to the flat directory
    cp "$md_file" "$target_file" || {
      error_log "Failed to copy $md_file to $target_file"
      continue
    }
    
    log "Copied markdown file: $(basename "$target_file")"
  done
}

# Create backup directory
log "Starting GitHub gists backup to $BACKUP_PATH"
mkdir -p "$BACKUP_PATH/public" "$BACKUP_PATH/private" "$MARKDOWN_DIR" || {
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
MAX_PAGES=20  # Safety limit to prevent infinite loops

while [ $page -le $MAX_PAGES ]; do
  log "Fetching page $page..."
  
  response=$(curl -s -u "$GITHUB_USERNAME:$GITHUB_TOKEN" \
    "https://api.github.com/users/$GITHUB_USERNAME/gists?page=$page&per_page=100")
  
  # Check for errors or empty response
  if [[ "$response" == "[]" ]] || [[ "$response" == *"message"* && "$response" == *"error"* ]]; then
    log "No more gists found on page $page"
    break
  fi
  
  # Count items in the response
  item_count=$(echo "$response" | jq '. | length')
  if [ "$item_count" -eq 0 ]; then
    log "No more gists found on page $page (empty array)"
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
        
        # Extract markdown files from this gist
        extract_markdown_files "$existing_folder" "$gist_id"
        
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
        
        # Extract markdown files from this gist
        extract_markdown_files "$gist_path" "$gist_id"
        
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

# Count markdown files
MD_COUNT=$(find "$MARKDOWN_DIR" -type f -name "*.md" | wc -l)
log "Total markdown files extracted: $MD_COUNT"

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