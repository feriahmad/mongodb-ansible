#!/bin/bash

# Script to install MongoDB 5.0.13 using Ansible
# Author: Cline
# Date: 2025-05-21

set -e

# Display banner
echo "====================================================="
echo "MongoDB 5.0.13 Installation Script for Ubuntu 24.04"
echo "====================================================="

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    echo "Ansible is not installed. Installing Ansible..."
    sudo apt update
    sudo apt install -y software-properties-common
    sudo apt-add-repository --yes --update ppa:ansible/ansible
    sudo apt install -y ansible
fi

echo "Ansible is installed. Proceeding with MongoDB installation..."

# Run the playbook
ansible-playbook -i inventory.ini mongodb_install.yml

# Check if installation was successful
if [ $? -eq 0 ]; then
    echo "====================================================="
    echo "MongoDB 5.0.13 installation completed successfully!"
    echo "====================================================="
    echo "To verify the installation, run:"
    echo "ansible-playbook -i inventory.ini mongodb_test.yml"
    echo ""
    echo "Or manually check with:"
    echo "systemctl status mongod"
    echo "mongosh"
    echo "mongod --version"
else
    echo "====================================================="
    echo "MongoDB installation failed. Please check the logs above."
    echo "====================================================="
    exit 1
fi

exit 0
