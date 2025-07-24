#!/bin/bash

# Script to manage MongoDB users
# Author: Cline
# Date: 2025-05-21

set -e

# Load environment variables from .env file
source ./load_env.sh

# Display banner
echo "====================================================="
echo "MongoDB User Management Script"
echo "====================================================="

# Default values
ACTION=""
USERNAME=""
PASSWORD=""
DATABASE="admin"
ROLES=""
ADMIN_USER="${MONGODB_ADMIN_USER:-}"
ADMIN_PASS="${MONGODB_ADMIN_PASS:-}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --create)
        ACTION="create"
        shift
        ;;
        --delete)
        ACTION="delete"
        shift
        ;;
        --list)
        ACTION="list"
        shift
        ;;
        --username)
        USERNAME="$2"
        shift
        shift
        ;;
        --password)
        PASSWORD="$2"
        shift
        shift
        ;;
        --database)
        DATABASE="$2"
        shift
        shift
        ;;
        --roles)
        ROLES="$2"
        shift
        shift
        ;;
        --admin-user)
        ADMIN_USER="$2"
        shift
        shift
        ;;
        --admin-pass)
        ADMIN_PASS="$2"
        shift
        shift
        ;;
        --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --create                Create a new user"
        echo "  --delete                Delete an existing user"
        echo "  --list                  List all users"
        echo "  --username USER         Username for the operation"
        echo "  --password PASS         Password for the new user"
        echo "  --database DB           Database for the user (default: admin)"
        echo "  --roles ROLES           Comma-separated list of roles (e.g., readWrite,dbAdmin)"
        echo "  --admin-user USER       Admin username for authentication"
        echo "  --admin-pass PASS       Admin password for authentication"
        echo "  --help                  Show this help message"
        echo ""
        echo "Examples:"
        echo "  Create a user:"
        echo "    $0 --create --username myuser --password mypass --database mydb --roles readWrite,dbAdmin --admin-user admin --admin-pass adminpass"
        echo ""
        echo "  Delete a user:"
        echo "    $0 --delete --username myuser --database mydb --admin-user admin --admin-pass adminpass"
        echo ""
        echo "  List all users:"
        echo "    $0 --list --admin-user admin --admin-pass adminpass"
        exit 0
        ;;
        *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
done

# Validate action
if [ -z "$ACTION" ]; then
    echo "Error: No action specified. Use --create, --delete, or --list"
    exit 1
fi

# Validate admin credentials
if [ -z "$ADMIN_USER" ] || [ -z "$ADMIN_PASS" ]; then
    echo "Error: Admin username and password are required"
    exit 1
fi

# Validate user credentials for create action
if [ "$ACTION" = "create" ]; then
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        echo "Error: Username and password are required for create action"
        exit 1
    fi
    
    if [ -z "$ROLES" ]; then
        echo "Error: Roles are required for create action"
        echo "Common roles: read, readWrite, dbAdmin, userAdmin, clusterAdmin, readAnyDatabase, readWriteAnyDatabase, userAdminAnyDatabase, dbAdminAnyDatabase"
        exit 1
    fi
fi

# Validate username for delete action
if [ "$ACTION" = "delete" ] && [ -z "$USERNAME" ]; then
    echo "Error: Username is required for delete action"
    exit 1
fi

# Create Ansible playbook for user management
cat > mongodb_users.yml << EOF
---
- name: Manage MongoDB Users
  hosts: mongodb
  become: yes
  vars_files:
    - vars/mongodb_vars.yml
  vars:
    action: "${ACTION}"
    username: "${USERNAME}"
    password: "${PASSWORD}"
    database: "${DATABASE}"
    roles: "${ROLES}"
  tasks:
    - name: Create MongoDB user
      shell: |
        mongosh --authenticationDatabase admin -u {{ mongodb_admin_user }} -p {{ mongodb_admin_pass }} --eval '
          db = db.getSiblingDB("{{ database }}");
          db.createUser({
            user: "{{ username }}",
            pwd: "{{ password }}",
            roles: [
              {% for role in roles.split(",") %}
                { role: "{{ role | trim }}", db: "{{ database }}" }{{ "," if not loop.last else "" }}
              {% endfor %}
            ]
          });
        '
      register: create_result
      changed_when: false
      when: action == "create"

    - name: Delete MongoDB user
      shell: |
        mongosh --authenticationDatabase admin -u {{ mongodb_admin_user }} -p {{ mongodb_admin_pass }} --eval '
          db = db.getSiblingDB("{{ database }}");
          db.dropUser("{{ username }}");
        '
      register: delete_result
      changed_when: false
      when: action == "delete"

    - name: List MongoDB users
      shell: |
        mongosh --authenticationDatabase admin -u {{ mongodb_admin_user }} -p {{ mongodb_admin_pass }} --eval '
          db = db.getSiblingDB("admin");
          db.system.users.find({}, {user: 1, db: 1, roles: 1, _id: 0}).pretty();
        '
      register: list_result
      changed_when: false
      when: action == "list"

    - name: Display create result
      debug:
        msg: "{{ create_result.stdout_lines }}"
      when: action == "create" and create_result.rc == 0

    - name: Display delete result
      debug:
        msg: "{{ delete_result.stdout_lines }}"
      when: action == "delete" and delete_result.rc == 0

    - name: Display user list
      debug:
        msg: "{{ list_result.stdout_lines }}"
      when: action == "list" and list_result.rc == 0
EOF

# Run the user management playbook
echo "Executing MongoDB user management action: $ACTION"
if [ "$ACTION" = "create" ]; then
    echo "- Creating user: $USERNAME in database: $DATABASE with roles: $ROLES"
elif [ "$ACTION" = "delete" ]; then
    echo "- Deleting user: $USERNAME from database: $DATABASE"
elif [ "$ACTION" = "list" ]; then
    echo "- Listing all users"
fi
echo

ansible-playbook -i inventory.ini mongodb_users.yml --extra-vars "mongodb_admin_user=${ADMIN_USER} mongodb_admin_pass=${ADMIN_PASS}"

# Check if operation was successful
if [ $? -eq 0 ]; then
    echo "====================================================="
    echo "MongoDB user management operation completed successfully!"
    echo "====================================================="
    
    # Clean up playbook
    rm mongodb_users.yml
else
    echo "====================================================="
    echo "MongoDB user management operation failed. Please check the logs above."
    echo "====================================================="
    rm mongodb_users.yml
    exit 1
fi

exit 0
