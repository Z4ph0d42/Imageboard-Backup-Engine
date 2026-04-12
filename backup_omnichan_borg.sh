#!/bin/bash
# =================================================================
# OMNI-CHAN BORG BACKUP SCRIPT
# Version: 2.4 - Universal Docker Engine (Mongo & MariaDB)
# =================================================================

# --- 1. LOAD CONFIG ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
else
    echo "[ERROR] config.env not found!"
    exit 1
fi

ARCHIVE_NAME="${SITE_NAME:-omnichan}-$(date +%Y-%m-%dT%H:%M:%S)"
TEMP_DUMP="/tmp/db_dump.archive"

trap 'rm -f "$TEMP_DUMP"' EXIT

echo "--- Starting Backup for [$SITE_NAME] at $(date) ---"
export BORG_PASSPHRASE

# --- 2. DATABASE DUMP STEP ---
echo "Step 1/3: Dumping $DB_TYPE database from $DK_DB_CONTAINER..."

if [ "$DB_TYPE" == "mongodb" ]; then
    docker exec "$DK_DB_CONTAINER" mongodump \
        --username "$DB_USER" --password "$DB_PASS" \
        --authenticationDatabase admin --archive > "$TEMP_DUMP"

elif [ "$DB_TYPE" == "mariadb" ] || [ "$DB_TYPE" == "mysql" ]; then
    docker exec "$DK_DB_CONTAINER" mariadb-dump \
        -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$TEMP_DUMP"
else
    echo "  [ERROR] Unknown DB_TYPE: $DB_TYPE"
    exit 1
fi

if [ $? -ne 0 ]; then echo "  [ERROR] DB Dump failed!"; exit 1; fi

# --- 3. BORG ARCHIVE STEP ---
echo "Step 2/3: Creating Borg archive..."
borg create --stats --progress              \
    "$BORG_REPO::$ARCHIVE_NAME"             \
    "$TEMP_DUMP"                            \
    "$DK_APP_DIR"
    
if [ $? -ne 0 ]; then echo "  [ERROR] Borg failed!"; exit 1; fi

# --- 4. PRUNE ---
echo "Step 3/3: Pruning old backups..."
borg prune -v --list --keep-daily=7 --keep-weekly=4 "$BORG_REPO"

echo "✅ Backup for $SITE_NAME Complete! ✅"