#!/bin/bash

# Script to backup MongoDB databases
# Author: Cline
# Date: 2025-05-21

set -e

# Load environment variables from .env file
source ./load_env.sh

# Display banner
echo "====================================================="
echo "MongoDB Backup Script"
echo "====================================================="

source extract_yaml_vars.sh vars/mongodb_vars.yml

# Set default backup directory
BACKUP_DIR="${MONGODB_BACKUP_DIR:-/tmp/mongodb_backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"

# Set admin credentials
ADMIN_USER="${MONGODB_ADMIN_USER:-}"
ADMIN_PASS="${MONGODB_ADMIN_PASS:-}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --dir)
        BACKUP_DIR="$2"
        BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"
        shift
        shift
        ;;
        --db)
        SPECIFIC_DB="$2"
        shift
        shift
        ;;
        --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --dir DIR    Specify backup directory (default: /tmp/mongodb_backups)"
        echo "  --db DB      Backup only the specified database"
        echo "  --help       Show this help message"
        exit 0
        ;;
        *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
done

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_PATH"
echo "Backup directory: $BACKUP_PATH"


# Run the backup directly using MongoDB commands
echo "Starting MongoDB backup..."

# Get list of databases
if [ "${SPECIFIC_DB:-all}" == "all" ]; then
    echo "Getting list of databases..."
    DATABASES=$(mongosh --authenticationDatabase admin -u "${ADMIN_USER}" -p "${ADMIN_PASS}" --quiet --eval "JSON.stringify(db.adminCommand('listDatabases').databases.map(function(d) { return d.name }))" | grep -v "^Error")
    
    # Check if the command was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to get list of databases"
        rm mongodb_backup.yml
        exit 1
    fi
    
    # Parse the JSON string
    DATABASES=$(echo $DATABASES | sed 's/\[\|\]//g' | sed 's/"//g' | sed 's/,/ /g')
else
    DATABASES="${SPECIFIC_DB}"
fi

# Backup each database
for DB in $DATABASES; do
    # Skip system databases
    if [ "$DB" != "admin" ] && [ "$DB" != "config" ] && [ "$DB" != "local" ]; then
        echo "Backing up database: $DB"
        mongodump --authenticationDatabase admin -u "${ADMIN_USER}" -p "${ADMIN_PASS}" --db=$DB --out="${BACKUP_PATH}" --gzip
        
        # Check if the backup was successful
        if [ $? -eq 0 ]; then
            echo "Successfully backed up database: $DB"
        else
            echo "Error: Failed to backup database: $DB"
        fi
    fi
done

# Create backup info file
echo "Creating backup info file..."
cat > "${BACKUP_PATH}/backup_info.txt" << EOF
Backup created: $(date)
MongoDB version: $(mongod --version 2>/dev/null || echo "Unknown")
Databases: $(echo $DATABASES | tr ' ' ', ')
EOF

# Check if at least one database was backed up
if [ -d "${BACKUP_PATH}" ] && [ "$(ls -A ${BACKUP_PATH})" ]; then
    echo "====================================================="
    echo "MongoDB backup completed successfully!"
    echo "====================================================="
    echo "Backup location: $BACKUP_PATH"
    echo ""
    echo "To restore from this backup, use:"
    echo "mongorestore --gzip $BACKUP_PATH"
    
else
    echo "====================================================="
    echo "MongoDB backup failed. Please check the logs above."
    echo "====================================================="
    exit 1
fi

exit 0
