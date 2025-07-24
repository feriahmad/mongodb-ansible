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

# Create Ansible playbook for backup
cat > mongodb_backup.yml << EOF
---
- name: Backup MongoDB databases
  hosts: mongodb
  become: yes
  vars:
    backup_path: "${BACKUP_PATH}"
    specific_db: "${SPECIFIC_DB:-all}"
  tasks:
    - name: Create backup directory
      file:
        path: "{{ backup_path }}"
        state: directory
        mode: '0755'

    - name: Get list of databases
      shell: mongosh --authenticationDatabase admin -u {{ lookup('env', 'MONGODB_ADMIN_USER') }} -p {{ lookup('env', 'MONGODB_ADMIN_PASS') }} --quiet --eval "db.adminCommand('listDatabases').databases.map(function(d) { return d.name })"
      register: db_list
      changed_when: false
      when: specific_db == "all"

    - name: Parse database list
      set_fact:
        databases: "{{ db_list.stdout | from_json }}"
      when: specific_db == "all"

    - name: Set single database
      set_fact:
        databases: ["{{ specific_db }}"]
      when: specific_db != "all"

    - name: Backup databases
      shell: mongodump --authenticationDatabase admin -u {{ lookup('env', 'MONGODB_ADMIN_USER') }} -p {{ lookup('env', 'MONGODB_ADMIN_PASS') }} --db={{ item }} --out={{ backup_path }} --gzip
      loop: "{{ databases }}"
      when: item != "admin" and item != "config" and item != "local"
      register: backup_result

    - name: Display backup results
      debug:
        msg: "Backed up database: {{ item.item }}"
      loop: "{{ backup_result.results }}"
      when: item.rc == 0

    - name: Create backup info file
      copy:
        dest: "{{ backup_path }}/backup_info.txt"
        content: |
          Backup created: $(date)
          MongoDB version: $(mongod --version | head -n 1)
          Databases: {{ databases | join(', ') }}
EOF

# Run the backup playbook
echo "Starting MongoDB backup..."
ansible-playbook -i inventory.ini mongodb_backup.yml

# Check if backup was successful
if [ $? -eq 0 ]; then
    echo "====================================================="
    echo "MongoDB backup completed successfully!"
    echo "====================================================="
    echo "Backup location: $BACKUP_PATH"
    echo ""
    echo "To restore from this backup, use:"
    echo "mongorestore --gzip $BACKUP_PATH"
    
    # Clean up playbook
    rm mongodb_backup.yml
else
    echo "====================================================="
    echo "MongoDB backup failed. Please check the logs above."
    echo "====================================================="
    rm mongodb_backup.yml
    exit 1
fi

exit 0
