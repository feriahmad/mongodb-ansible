#!/bin/bash

# Script to uninstall MongoDB 5.0.13 using Ansible
# Author: Cline
# Date: 2025-05-21

set -e

# Display banner
echo "====================================================="
echo "MongoDB 5.0.13 Uninstallation Script for Ubuntu 20.04"
echo "====================================================="

# Confirm uninstallation
echo "This script will completely remove MongoDB 5.0.13 from your system."
echo "All data will be lost. Make sure you have a backup if needed."
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Create uninstall playbook
cat > mongodb_uninstall.yml << 'EOF'
---
- name: Uninstall MongoDB 5.0.13
  hosts: mongodb
  become: yes
  vars_files:
    - vars/mongodb_vars.yml
  tasks:
    - name: Stop MongoDB service
      systemd:
        name: "{{ mongodb_service_name }}"
        state: stopped
        enabled: no
      ignore_errors: yes

    - name: Remove MongoDB packages
      apt:
        name:
          - mongodb-org
          - mongodb-org-database
          - mongodb-org-server
          - mongodb-org-mongos
          - mongodb-org-tools
        state: absent
        purge: yes

    - name: Remove MongoDB repository
      apt_repository:
        repo: "{{ mongodb_repo }}"
        state: absent
        filename: "{{ mongodb_repo_file }}"

    - name: Remove MongoDB GPG key
      apt_key:
        url: "{{ mongodb_gpg_key }}"
        state: absent
      ignore_errors: yes

    - name: Remove MongoDB data and log directories
      file:
        path: "{{ item }}"
        state: absent
      loop:
        - "{{ mongodb_data_dir }}"
        - "{{ mongodb_log_dir }}"
        - "{{ mongodb_config_file }}"

    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Clean apt
      command: apt autoremove -y
      changed_when: false
EOF

echo "Running uninstall playbook..."

# Run the uninstall playbook
ansible-playbook -i inventory.ini mongodb_uninstall.yml

# Check if uninstallation was successful
if [ $? -eq 0 ]; then
    echo "====================================================="
    echo "MongoDB 5.0.13 uninstallation completed successfully!"
    echo "====================================================="
    
    # Clean up uninstall playbook
    rm mongodb_uninstall.yml
else
    echo "====================================================="
    echo "MongoDB uninstallation failed. Please check the logs above."
    echo "====================================================="
    exit 1
fi

exit 0
