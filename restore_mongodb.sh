#!/bin/bash

# Script to restore MongoDB databases from backup
# Author: Cline
# Date: 2025-05-21

set -e

# Load environment variables from .env file
source ./load_env.sh

# Display banner
echo "====================================================="
echo "MongoDB Restore Script"
echo "====================================================="

# Default values
BACKUP_PATH=""
SPECIFIC_DB=""
DROP_EXISTING=false
ADMIN_USER="${MONGODB_ADMIN_USER:-}"
ADMIN_PASS="${MONGODB_ADMIN_PASS:-}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --path)
        BACKUP_PATH="$2"
        shift
        shift
        ;;
        --db)
        SPECIFIC_DB="$2"
        shift
        shift
        ;;
        --drop)
        DROP_EXISTING=true
        shift
        ;;
        --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --path PATH  Specify backup directory path (required)"
        echo "  --db DB      Restore only the specified database"
        echo "  --drop       Drop existing collections before restoring"
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

# Check if backup path is provided
if [ -z "$BACKUP_PATH" ]; then
    echo "Error: Backup path is required"
    echo "Use --path to specify the backup directory"
    echo "Example: $0 --path /tmp/mongodb_backups/20250521_120000"
    exit 1
fi

# Check if backup path exists
if [ ! -d "$BACKUP_PATH" ]; then
    echo "Error: Backup directory does not exist: $BACKUP_PATH"
    exit 1
fi

# Create Ansible playbook for restore
cat > mongodb_restore.yml << EOF
---
- name: Restore MongoDB databases from backup
  hosts: mongodb
  become: yes
  vars:
    backup_path: "${BACKUP_PATH}"
    specific_db: "${SPECIFIC_DB}"
    drop_existing: ${DROP_EXISTING}
  tasks:
    - name: Check if backup directory exists
      stat:
        path: "{{ backup_path }}"
      register: backup_dir

    - name: Fail if backup directory doesn't exist
      fail:
        msg: "Backup directory does not exist: {{ backup_path }}"
      when: not backup_dir.stat.exists

    - name: Display backup info
      shell: cat {{ backup_path }}/backup_info.txt
      register: backup_info
      changed_when: false
      ignore_errors: yes

    - name: Show backup info
      debug:
        msg: "{{ backup_info.stdout_lines }}"
      when: backup_info.rc == 0

    - name: Restore all databases
      shell: >
        mongorestore --authenticationDatabase admin -u {{ lookup('env', 'MONGODB_ADMIN_USER') }} -p {{ lookup('env', 'MONGODB_ADMIN_PASS') }} --gzip {{ '--drop' if drop_existing else '' }} {{ backup_path }}
      when: specific_db == ""
      register: restore_result

    - name: Restore specific database
      shell: >
        mongorestore --authenticationDatabase admin -u {{ lookup('env', 'MONGODB_ADMIN_USER') }} -p {{ lookup('env', 'MONGODB_ADMIN_PASS') }} --gzip {{ '--drop' if drop_existing else '' }} --db={{ specific_db }} {{ backup_path }}/{{ specific_db }}
      when: specific_db != ""
      register: restore_result

    - name: Display restore result
      debug:
        msg: "{{ restore_result.stdout_lines }}"
EOF

# Run the restore playbook
echo "Starting MongoDB restore from $BACKUP_PATH..."
if [ -n "$SPECIFIC_DB" ]; then
    echo "Restoring database: $SPECIFIC_DB"
fi
if [ "$DROP_EXISTING" = true ]; then
    echo "Warning: Existing collections will be dropped before restore"
fi

ansible-playbook -i inventory.ini mongodb_restore.yml

# Check if restore was successful
if [ $? -eq 0 ]; then
    echo "====================================================="
    echo "MongoDB restore completed successfully!"
    echo "====================================================="
    
    # Clean up playbook
    rm mongodb_restore.yml
else
    echo "====================================================="
    echo "MongoDB restore failed. Please check the logs above."
    echo "====================================================="
    rm mongodb_restore.yml
    exit 1
fi

exit 0
