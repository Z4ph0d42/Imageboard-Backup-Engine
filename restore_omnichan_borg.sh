#!/bin/bash
# =================================================================
# OMNI-CHAN BORG RESTORE SCRIPT
# Version: 2.0 - Interactive Dual-Site Docker Recovery
# =================================================================

# --- 1. LOAD CONFIG ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
else
    echo "❌ [ERROR] config.env not found! Please copy a site .env file first."
    exit 1
fi

export BORG_PASSPHRASE
TEMP_DUMP="/tmp/db_dump.archive"

echo "=========================================================="
echo "🛡️  INITIATING RESTORE PROTOCOL FOR: [$SITE_NAME] 🛡️"
echo "=========================================================="
echo ""
echo "Fetching available archives from James's Pi..."
echo ""

# --- 2. LIST ARCHIVES ---
borg list "$BORG_REPO" --prefix "$SITE_NAME"

echo ""
echo "----------------------------------------------------------"
echo -n "Enter the exact archive name to restore (e.g., $SITE_NAME-2026-04-12T16:05:26): "
read ARCHIVE_NAME

if [ -z "$ARCHIVE_NAME" ]; then
    echo "❌ [ERROR] No archive name provided. Aborting."
    exit 1
fi

# --- 3. EXTRACT DATABASE DUMP ---
echo ""
echo "Step 1/3: Extracting database dump from Borg archive..."
cd / && borg extract "$BORG_REPO::$ARCHIVE_NAME" tmp/db_dump.archive

if [ ! -f "$TEMP_DUMP" ]; then
    echo "❌ [ERROR] Failed to extract database dump."
    exit 1
fi

# --- 4. INJECT DATABASE INTO DOCKER ---
echo "Step 2/3: Injecting $DB_TYPE data into container [$DK_DB_CONTAINER]..."

if [ "$DB_TYPE" == "mongodb" ]; then
    sudo docker exec -i "$DK_DB_CONTAINER" mongorestore \
        --username "$DB_USER" --password "$DB_PASS" \
        --authenticationDatabase admin --drop --archive < "$TEMP_DUMP"

elif [ "$DB_TYPE" == "mariadb" ] || [ "$DB_TYPE" == "mysql" ]; then
    sudo docker exec -i "$DK_DB_CONTAINER" mariadb \
        -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$TEMP_DUMP"
else
    echo "❌ [ERROR] Unknown DB_TYPE: $DB_TYPE"
    exit 1
fi

rm -f "$TEMP_DUMP"
echo "✅ Database restore complete!"

# --- 5. OPTIONAL: RESTORE WEB FILES ---
echo ""
echo "Step 3/3: Restore Web Files & Images"
echo "⚠️ WARNING: This will overwrite current files in your Docker/Web folders."
echo -n "Type 'y' to restore files, or 'n' to skip (for DB-only restore): "
read RESTORE_FILES

if [ "$RESTORE_FILES" == "y" ]; then
    echo "Extracting files to host..."
    PATHS_NO_SLASH=""
    for path in $DK_APP_DIR; do PATHS_NO_SLASH="$PATHS_NO_SLASH ${path#/}"; done
    cd / && borg extract -v --list "$BORG_REPO::$ARCHIVE_NAME" $PATHS_NO_SLASH
    echo "✅ File restore complete!"
else
    echo "⏭️ Skipping file restore."
fi

echo ""
echo "🎉 RESTORE PROTOCOL COMPLETE FOR [$SITE_NAME] 🎉"