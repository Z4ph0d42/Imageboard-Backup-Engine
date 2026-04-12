#!/bin/bash
# =================================================================
# OMNI-CHAN BORG BACKUP SCRIPT
# Author: Z4ph0d42
# Version: 2.3 - Fully De-coupled (Safe for Public GitHub)
# =================================================================

# --- 1. LOAD SENSITIVE CONFIG ---
# Find the folder where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the secret configuration file
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
else
    echo "  [ERROR] config.env not found in $SCRIPT_DIR"
    echo "  Please create it before running this script."
    exit 1
fi

# Universal Archive Name
ARCHIVE_NAME="omnichan-$(date +%Y-%m-%dT%H:%M:%S)"
BM_TEMP_DUMP="/tmp/vichan_db_dump.sql"
DK_TEMP_DUMP="/tmp/jschan_db_dump.archive"

# --- 2. SELF-CLEANING MECHANISM ---
# Ensures temp DB dumps are ALWAYS removed on exit
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
    if [ $? -ne 0 ]; then echo "  [ERROR] Database dump failed."; exit 1; fi

    echo "Step 2/3: Creating Borg archive..."
    borg create --stats --progress              \
        "$BORG_REPO::$ARCHIVE_NAME"             \
        "$BM_SOURCE_DIR"                        \
        "$BM_TEMP_DUMP"
    if [ $? -ne 0 ]; then echo "  [ERROR] Borg creation failed."; exit 1; fi

# =================================================================
# --- ROUTINE B: DOCKER (JSCHAN) ---
# =================================================================
elif [ "$BACKUP_MODE" == "docker" ]; then
    echo "Step 1/3: Extracting MongoDB from Docker Container..."
    docker exec "$DK_MONGO_CONTAINER" mongodump \
        --username "$DK_MONGO_USER" \
        --password "$DK_MONGO_PASS" \
        --authenticationDatabase admin \
        --archive > "$DK_TEMP_DUMP"
    
    if [ $? -ne 0 ]; then echo "  [ERROR] MongoDB extraction failed."; exit 1; fi

    echo "Step 2/3: Creating Borg archive..."
    borg create --stats --progress              \
        "$BORG_REPO::$ARCHIVE_NAME"             \
        "$DK_TEMP_DUMP"                         \
        "$DK_APP_DIR/static"                    \
        "$DK_APP_DIR/configs/secrets.js"        \
        "$DK_APP_DIR/docker-compose.yml"
    if [ $? -ne 0 ]; then echo "  [ERROR] Borg creation failed."; exit 1; fi

else
    echo "  [ERROR] Invalid BACKUP_MODE set in config.env."
    exit 1
fi

# =================================================================
# --- Step 3: UNIVERSAL PRUNING ---
# =================================================================
echo "Step 3/3: Pruning old backups..."
borg prune -v --list                            \
    --keep-daily=${KEEP_DAILY:-7}               \
    --keep-weekly=${KEEP_WEEKLY:-4}             \
    --keep-monthly=${KEEP_MONTHLY:-6}           \
    "$BORG_REPO"

if [ $? -ne 0 ]; then echo "  [ERROR] Pruning failed."; exit 1; fi

echo "------------------------------------------------------"
echo "✅ Omni-Chan Backup Complete! ✅"
echo "------------------------------------------------------"