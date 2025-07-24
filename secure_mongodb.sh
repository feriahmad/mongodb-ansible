#!/bin/bash

# Script to secure MongoDB installation
# Author: Cline
# Date: 2025-05-21

set -e

# Load environment variables from .env file
source ./load_env.sh

# Display banner
echo "====================================================="
echo "MongoDB Security Configuration Script"
echo "====================================================="

# Default values
ENABLE_AUTH=true
ADMIN_USER="${MONGODB_ADMIN_USER:-}"
ADMIN_PASS="${MONGODB_ADMIN_PASS:-}"
ENABLE_TLS=false
BIND_IP="${MONGODB_BIND_IP:-127.0.0.1}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --no-auth)
        ENABLE_AUTH=false
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
        --enable-tls)
        ENABLE_TLS=true
        shift
        ;;
        --bind-ip)
        BIND_IP="$2"
        shift
        shift
        ;;
        --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --no-auth           Disable authentication (enabled by default)"
        echo "  --admin-user USER   Set admin username (will prompt if not provided)"
        echo "  --admin-pass PASS   Set admin password (will prompt if not provided)"
        echo "  --enable-tls        Enable TLS/SSL (disabled by default)"
        echo "  --bind-ip IP        Set bind IP address (default: 127.0.0.1)"
        echo "  --help              Show this help message"
        exit 0
        ;;
        *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
done

# Prompt for admin credentials if not provided and auth is enabled
if [ "$ENABLE_AUTH" = true ]; then
    if [ -z "$ADMIN_USER" ]; then
        read -p "Enter admin username: " ADMIN_USER
    fi
    
    if [ -z "$ADMIN_PASS" ]; then
        read -s -p "Enter admin password: " ADMIN_PASS
        echo
        read -s -p "Confirm admin password: " ADMIN_PASS_CONFIRM
        echo
        
        if [ "$ADMIN_PASS" != "$ADMIN_PASS_CONFIRM" ]; then
            echo "Error: Passwords do not match"
            exit 1
        fi
    fi
    
    # Validate username and password
    if [ -z "$ADMIN_USER" ] || [ -z "$ADMIN_PASS" ]; then
        echo "Error: Admin username and password are required when authentication is enabled"
        exit 1
    fi
fi

# Create Ansible playbook for security configuration
cat > mongodb_secure.yml << EOF
---
- name: Secure MongoDB Installation
  hosts: mongodb
  become: yes
  vars_files:
    - vars/mongodb_vars.yml
  vars:
    enable_auth: ${ENABLE_AUTH}
    enable_tls: ${ENABLE_TLS}
    bind_ip: "${BIND_IP}"
  tasks:
    - name: Check if MongoDB is installed
      command: which mongod
      register: mongod_installed
      changed_when: false
      ignore_errors: yes
      
    - name: Fail if MongoDB is not installed
      fail:
        msg: "MongoDB is not installed. Please install MongoDB first using the install_mongodb.sh script."
      when: mongod_installed.rc != 0

    - name: Stop MongoDB service
      systemd:
        name: "{{ mongodb_service_name }}"
        state: stopped

    - name: Update MongoDB configuration for security
      template:
        src: templates/mongod.conf.j2
        dest: "{{ mongodb_config_file }}"
        owner: root
        group: root
        mode: '0644'
        backup: yes
      vars:
        mongodb_security_auth: "{{ enable_auth }}"
        mongodb_bind_ip: "{{ bind_ip }}"
        mongodb_tls_enabled: "{{ enable_tls }}"

    - name: Create custom systemd service file for temporary instance
      template:
        src: templates/mongod.service.j2
        dest: /lib/systemd/system/mongod.service
        owner: root
        group: root
        mode: '0644'
      register: service_file_updated

    - name: Reload systemd if service file was updated
      systemd:
        daemon_reload: yes
      when: service_file_updated.changed

    - name: Start MongoDB service without authentication for initial setup
      systemd:
        name: "{{ mongodb_service_name }}"
        state: started
      when: enable_auth
      ignore_errors: yes

    - name: Wait for MongoDB to start
      wait_for:
        port: "{{ mongodb_port }}"
        delay: 5
        timeout: 30
      when: enable_auth

    - name: Create admin user
      shell: |
        mongosh --port {{ mongodb_port }} --eval '
          db = db.getSiblingDB("admin");
          db.createUser({
            user: "{{ mongodb_admin_user }}",
            pwd: "{{ mongodb_admin_pass }}",
            roles: [
              { role: "userAdminAnyDatabase", db: "admin" },
              { role: "readWriteAnyDatabase", db: "admin" },
              { role: "dbAdminAnyDatabase", db: "admin" },
              { role: "clusterAdmin", db: "admin" }
            ]
          });
          db.auth("{{ mongodb_admin_user }}", "{{ mongodb_admin_pass }}");
        '
      register: create_user_result
      changed_when: false
      when: enable_auth
      ignore_errors: yes

    - name: Stop temporary MongoDB instance
      shell: mongosh --port {{ mongodb_port }} admin --eval "db.shutdownServer()"
      ignore_errors: yes
      when: enable_auth

    - name: Start MongoDB service with security settings
      systemd:
        name: "{{ mongodb_service_name }}"
        state: started
        enabled: yes

    - name: Wait for MongoDB to start
      wait_for:
        port: "{{ mongodb_port }}"
        delay: 5
        timeout: 30

    - name: Verify MongoDB security settings
      shell: >
        mongosh --port {{ mongodb_port }} {{ '--authenticationDatabase admin -u ' + mongodb_admin_user + ' -p ' + mongodb_admin_pass if enable_auth else '' }} --eval "db.runCommand({ connectionStatus: 1 })"
      register: security_status
      changed_when: false
      ignore_errors: yes

    - name: Display security status
      debug:
        msg: "{{ security_status.stdout_lines }}"
EOF

# Run the security configuration playbook
echo "Configuring MongoDB security settings..."
if [ "$ENABLE_AUTH" = true ]; then
    echo "- Enabling authentication with admin user: $ADMIN_USER"
else
    echo "- Authentication disabled"
fi

if [ "$ENABLE_TLS" = true ]; then
    echo "- Enabling TLS/SSL"
else
    echo "- TLS/SSL disabled"
fi

echo "- Setting bind IP to: $BIND_IP"
echo

ansible-playbook -i inventory.ini mongodb_secure.yml --extra-vars "mongodb_admin_user=${ADMIN_USER} mongodb_admin_pass=${ADMIN_PASS}"

# Check if configuration was successful
if [ $? -eq 0 ]; then
    echo "====================================================="
    echo "MongoDB security configuration completed successfully!"
    echo "====================================================="
    
    if [ "$ENABLE_AUTH" = true ]; then
        echo "MongoDB is now secured with authentication."
        echo "Admin user: $ADMIN_USER"
        echo
        echo "To connect to MongoDB:"
        echo "mongosh --authenticationDatabase admin -u $ADMIN_USER -p <password>"
    fi
    
    # Clean up playbook
    rm mongodb_secure.yml
else
    echo "====================================================="
    echo "MongoDB security configuration failed. Please check the logs above."
    echo "====================================================="
    rm mongodb_secure.yml
    exit 1
fi

exit 0
