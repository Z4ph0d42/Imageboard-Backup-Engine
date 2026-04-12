#!/bin/bash
# =================================================================
# OMNI-CHAN BORG BACKUP SCRIPT
# Author: Z4ph0d42
# Version: 2.0 - Dual-Engine (Bare-Metal & Docker)
# =================================================================

# --- 1. CORE CONFIGURATION ---
# Set to "bare-metal" (Vichan) OR "docker" (JSchan)
BACKUP_MODE="docker"

# Borg Repository Settings (Same for both setups)
BORG_REPO="user@hostname:/path/to/your/borg_repo"
BORG_PASSPHRASE="your_secret_borg_passphrase"
ARCHIVE_NAME="omnichan-$(date +%Y-%m-%dT%H:%M:%S)"

# Pruning settings (how many backups to keep)
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=6

# --- 2. BARE-METAL SETTINGS (Netherchan / Vichan) ---
BM_DB_NAME="your_db_name"
BM_DB_USER="your_db_user"
BM_DB_PASS="your_secret_database_password"
BM_SOURCE_DIR="/var/www/netherchan.org"
BM_TEMP_DUMP="/tmp/vichan_db_dump.sql"

# --- 3. DOCKER SETTINGS (Fogchan / JSchan) ---
# The exact name of your MongoDB container
DK_MONGO_CONTAINER="42chan-dev-db"
# The path on your host machine where the docker-compose.yml lives
DK_APP_DIR="/opt/42chan-dev-docker/42chan"
DK_TEMP_DUMP="/tmp/jschan_db_dump.archive"

# =================================================================
# --- Self-Cleaning Mechanism ---
# Ensures temp DB dumps are ALWAYS removed when the script exits
trap 'rm -f "$BM_TEMP_DUMP" "$DK_TEMP_DUMP"' EXIT

echo "--- Starting Omni-Chan Borg Backup Process $(date '+%a %b %d %I:%M:%S %p %Z %Y') ---"
echo "Active Mode: [$BACKUP_MODE]"

export BORG_PASSPHRASE

# =================================================================
# --- ROUTINE A: BARE METAL (VICHAN) ---
# =================================================================
if [ "$BACKUP_MODE" == "bare-metal" ]; then
    echo "Step 1/3: Dumping MariaDB/MySQL database..."
    mysqldump -u "$BM_DB_USER" -p"$BM_DB_PASS" "$BM_DB_NAME" > "$BM_TEMP_DUMP"
    if [ $? -ne 0 ]; then echo "  [ERROR] Failed to dump database. Aborting."; exit 1; fi

    echo "Step 2/3: Creating Borg archive..."
    borg create --stats --progress              \
        "$BORG_REPO::$ARCHIVE_NAME"             \
        "$BM_SOURCE_DIR"                        \
        "$BM_TEMP_DUMP"
    if [ $? -ne 0 ]; then echo "  [ERROR] Borg create failed. Aborting."; exit 1; fi

# =================================================================
# --- ROUTINE B: DOCKER (JSCHAN) ---
# =================================================================
elif [ "$BACKUP_MODE" == "docker" ]; then
    echo "Step 1/3: Extracting MongoDB from Docker Container..."
    # We execute mongodump inside the container, but output it as a stream directly to our host's temp folder!
    docker exec "$DK_MONGO_CONTAINER" mongodump --archive > "$DK_TEMP_DUMP"
    if [ $? -ne 0 ]; then echo "  [ERROR] Failed to extract MongoDB. Aborting."; exit 1; fi

    echo "Step 2/3: Creating Borg archive..."
    # We backup the Database, the bridged Static folder, the Secrets, and the Compose file.
    borg create --stats --progress              \
        "$BORG_REPO::$ARCHIVE_NAME"             \
        "$DK_TEMP_DUMP"                         \
        "$DK_APP_DIR/static"                    \
        "$DK_APP_DIR/configs/secrets.js"        \
        "$DK_APP_DIR/docker-compose.yml"
    if [ $? -ne 0 ]; then echo "  [ERROR] Borg create failed. Aborting."; exit 1; fi

else
    echo "  [ERROR] Invalid BACKUP_MODE. Must be 'bare-metal' or 'docker'."
    exit 1
fi

# =================================================================
# --- Step 3: UNIVERSAL PRUNING ---
# =================================================================
echo "Step 3/3: Pruning and cleaning up old backups..."
borg prune -v --list                            \
    --keep-daily=$KEEP_DAILY                    \
    --keep-weekly=$KEEP_WEEKLY                  \
    --keep-monthly=$KEEP_MONTHLY                \
    "$BORG_REPO"

if [ $? -ne 0 ]; then
    echo "  [ERROR] Borg prune command failed."
    exit 1
fi

echo "------------------------------------------------------"
echo "✅ Omni-Chan Backup and Prune Complete! ✅"
echo "------------------------------------------------------"

exit 0