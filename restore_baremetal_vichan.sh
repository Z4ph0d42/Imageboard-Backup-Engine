#!/bin/bash
# =================================================================
# VICHAN BORG BACKUP SCRIPT
# Author: Z4ph0d42
# Version: 1.2 - Self-Cleaning
# =================================================================

# --- Configuration ---
# IMPORTANT: Fill in these variables with your actual credentials and paths before running.
# It is strongly recommended to use a .my.cnf file for database credentials
# instead of putting the password directly in this script.

# Database settings
DB_NAME="your_db_name"
DB_USER="your_db_user"
DB_PASS="your_secret_database_password"

# Borg settings
BORG_REPO="user@hostname:/path/to/your/borg_repo"
BORG_PASSPHRASE="your_secret_borg_passphrase"

# Backup settings
SOURCE_DIR="/path/to/your/website_files"
DB_DUMP_LOCATION="/tmp/db_dump.sql" # A temporary location for the database dump
ARCHIVE_NAME="website-$(date +%Y-%m-%dT%H:%M:%S)"

# Pruning settings (how many backups to keep)
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=6

# --- Self-Cleaning Mechanism ---
# This ensures the temp DB dump is ALWAYS removed when the script exits,
# whether it succeeds, fails, or is cancelled.
trap 'rm -f "$DB_DUMP_LOCATION"' EXIT

# --- Main Script ---
echo "--- Starting Borg Backup Process $(date '+%a %b %d %I:%M:%S %p %Z %Y') ---"

# Step 1: Dump the database to a temporary SQL file
echo "Step 1/3: Dumping database..."
mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$DB_DUMP_LOCATION"
if [ $? -ne 0 ]; then
    echo "  [ERROR] Failed to dump database. Aborting."
    exit 1
fi

# Step 2: Create a new Borg archive
echo "Step 2/3: Creating Borg archive..."
export BORG_PASSPHRASE
borg create --stats --progress              \
    "$BORG_REPO::$ARCHIVE_NAME"             \
    "$SOURCE_DIR"                           \
    "$DB_DUMP_LOCATION"

if [ $? -ne 0 ]; then
    echo "  [ERROR] Borg create command failed. Aborting."
    exit 1
fi

# Step 3: Prune old backups to save space
echo "Step 3/3: Pruning and cleaning up..."
borg prune -v --list                        \
    --keep-daily=$KEEP_DAILY                \
    --keep-weekly=$KEEP_WEEKLY              \
    --keep-monthly=$KEEP_MONTHLY            \
    "$BORG_REPO"

if [ $? -ne 0 ]; then
    echo "  [ERROR] Borg prune command failed."
    exit 1
fi

echo "------------------------------------"
echo "✅ Borg Backup and Prune Complete! ✅"
echo "------------------------------------"

exit 0