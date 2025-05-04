# GitHub Gists Backup Tool

*Last Updated: May 4th, 2025*

A bash script for programmatically backing up your GitHub Gists to a local directory.

## Overview

This tool allows you to create and maintain a complete backup of all your GitHub Gists (both public and private). It works incrementally, meaning you can run it periodically to keep your backups up-to-date without duplicating content.

## Features

- **Separate Storage**: Public and private Gists are stored in separate directories for better organization
- **Smart Naming**: Uses the first filename of each Gist to create meaningful directory names
- **Incremental Backups**: Only updates Gists that have changed since the last backup
- **Markdown Extraction**: Automatically extracts all markdown files into a flat directory structure
- **Pagination Safety**: Includes limits to prevent infinite loops when fetching large collections
- **Detailed Logging**: Provides comprehensive logs of the backup process
- **Error Handling**: Robust error detection and reporting

## How It Works

The script:
1. Fetches all your Gists using the GitHub API with proper pagination
2. Separates them into public and private categories
3. Uses the first filename of each Gist to create a meaningful directory name
4. Clones new Gists or updates existing ones
5. Extracts all markdown files into a flat directory structure for easy access
6. Handles filename conflicts by adding numeric suffixes
7. Maintains a marker file to track which Gists have been backed up

## GitHub Gists Structure

GitHub Gists are essentially mini-repositories. While many users (including the author) primarily use them for single markdown files, each Gist is stored as a Git repository with potentially multiple files. This script preserves this structure by cloning each Gist as a complete Git repository.

## Usage

1. Edit the configuration section at the top of the script:
   ```bash
   GITHUB_USERNAME="your_username"
   BACKUP_PATH="/path/to/backup/directory"
   GITHUB_TOKEN="your_github_token"
   ```

2. Make the script executable:
   ```bash
   chmod +x backup.sh
   ```

3. Run the script:
   ```bash
   ./backup.sh
   ```

## Security Recommendations

For better security, consider using environment variables instead of hardcoding your GitHub token:

1. Create a `.env` file:
   ```
   GITHUB_USERNAME=your_username
   GITHUB_TOKEN=your_github_token
   BACKUP_PATH=/path/to/backup
   ```

2. Modify the script to use these environment variables:
   ```bash
   # Load environment variables
   source .env
   
   # Use the loaded variables
   # GITHUB_USERNAME, GITHUB_TOKEN, and BACKUP_PATH should now be available
   ```

3. Add `.env` to your `.gitignore` file to prevent accidentally committing your credentials.

## Requirements

- `curl`: For API requests
- `jq`: For JSON parsing
- `git`: For cloning Gists

## Directory Structure

After running the script, you'll have the following directory structure:

```
backup_path/
├── public/           # Public Gists, each in its own directory
├── private/          # Private Gists, each in its own directory
└── markdown_files/   # All markdown files extracted from Gists
```

The `markdown_files` directory provides a convenient way to access all your markdown content without navigating through individual Gist directories.

## License

This script is provided as-is under the MIT License.
