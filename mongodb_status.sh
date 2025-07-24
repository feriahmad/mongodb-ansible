#!/bin/bash

# Script to check MongoDB status
# Author: Cline
# Date: 2025-05-21

set -e

# Display banner
echo "====================================================="
echo "MongoDB Status Check"
echo "====================================================="

# Load environment variables from .env file
source ./load_env.sh

# Set admin credentials
ADMIN_USER="${MONGODB_ADMIN_USER:-}"
ADMIN_PASS="${MONGODB_ADMIN_PASS:-}"

# Create Ansible playbook for status check
cat > mongodb_status.yml << EOF
---
- name: Check MongoDB Status
  hosts: mongodb
  become: yes
  vars_files:
    - vars/mongodb_vars.yml
  tasks:
    - name: Check if MongoDB is installed
      command: which mongod
      register: mongod_installed
      changed_when: false
      ignore_errors: yes

    - name: Set MongoDB installation status
      set_fact:
        mongodb_is_installed: "{{ mongod_installed.rc == 0 }}"

    - name: Get MongoDB version
      command: mongod --version
      register: mongodb_version
      changed_when: false
      ignore_errors: yes
      when: mongodb_is_installed

    - name: Check MongoDB service status
      command: systemctl status {{ mongodb_service_name }}
      register: service_status
      changed_when: false
      ignore_errors: yes
      when: mongodb_is_installed

    - name: Set MongoDB service running status
      set_fact:
        mongodb_is_running: "{{ service_status.rc == 0 }}"
      when: mongodb_is_installed

    - name: Get MongoDB server status
      shell: mongosh --authenticationDatabase admin -u {{ mongodb_admin_user }} -p {{ mongodb_admin_pass }} --quiet --eval "db.serverStatus()"
      register: server_status
      changed_when: false
      ignore_errors: yes
      when: mongodb_is_installed and mongodb_is_running

    - name: Get MongoDB database list
      shell: mongosh --authenticationDatabase admin -u {{ mongodb_admin_user }} -p {{ mongodb_admin_pass }} --quiet --eval "db.adminCommand('listDatabases')"
      register: db_list
      changed_when: false
      ignore_errors: yes
      when: mongodb_is_installed and mongodb_is_running

    - name: Get MongoDB connection info
      shell: mongosh --authenticationDatabase admin -u {{ mongodb_admin_user }} -p {{ mongodb_admin_pass }} --quiet --eval "db.runCommand({connectionStatus: 1})"
      register: connection_info
      changed_when: false
      ignore_errors: yes
      when: mongodb_is_installed and mongodb_is_running

    - name: Display MongoDB status summary
      debug:
        msg:
          - "====================================================="
          - "MongoDB Status Summary"
          - "====================================================="
          - "Installation: {{ 'Installed' if mongodb_is_installed else 'Not installed' }}"
          - "{{ 'Version: ' + mongodb_version.stdout_lines[0] if mongodb_is_installed else '' }}"
          - "{{ 'Service: ' + ('Running' if mongodb_is_running else 'Not running') if mongodb_is_installed else '' }}"
          - "{{ 'Port: ' + mongodb_port | string if mongodb_is_installed else '' }}"
          - "{{ 'Bind IP: ' + mongodb_bind_ip if mongodb_is_installed else '' }}"
          - "{{ 'Data directory: ' + mongodb_data_dir if mongodb_is_installed else '' }}"
          - "{{ 'Log directory: ' + mongodb_log_dir if mongodb_is_installed else '' }}"
          - "{{ 'Config file: ' + mongodb_config_file if mongodb_is_installed else '' }}"
          - "====================================================="

    - name: Display MongoDB server status
      debug:
        msg:
          - "MongoDB Server Status:"
          - "====================================================="
          - "{{ server_status.stdout | from_json | to_nice_json }}"
      when: mongodb_is_installed and mongodb_is_running and server_status.rc == 0
      ignore_errors: yes

    - name: Display MongoDB database list
      debug:
        msg:
          - "MongoDB Databases:"
          - "====================================================="
          - "{{ db_list.stdout | from_json | to_nice_json }}"
      when: mongodb_is_installed and mongodb_is_running and db_list.rc == 0
      ignore_errors: yes

    - name: Display MongoDB connection info
      debug:
        msg:
          - "MongoDB Connection Info:"
          - "====================================================="
          - "{{ connection_info.stdout | from_json | to_nice_json }}"
      when: mongodb_is_installed and mongodb_is_running and connection_info.rc == 0
      ignore_errors: yes
EOF

# Run the status check playbook
echo "Checking MongoDB status..."
ansible-playbook -i inventory.ini mongodb_status.yml --extra-vars "mongodb_admin_user=${ADMIN_USER} mongodb_admin_pass=${ADMIN_PASS}"

# Clean up playbook
rm mongodb_status.yml

exit 0
