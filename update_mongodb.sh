#!/bin/bash

# Script to update MongoDB using Ansible
# Author: Cline
# Date: 2025-05-21

set -e

# Display banner
echo "====================================================="
echo "MongoDB Update Script for Ubuntu 24.04 (using Ubuntu 22.04 repository)"
echo "====================================================="

# Get current version
current_version=$(grep "mongodb_version:" vars/mongodb_vars.yml | cut -d'"' -f2)
echo "Current MongoDB version: $current_version"

# Ask for new version
read -p "Enter the new MongoDB version (e.g., 5.0.4): " new_version

# Validate input
if [[ ! $new_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format. Please use the format: X.Y.Z"
    exit 1
fi

# Extract major version
major_version=$(echo $new_version | cut -d'.' -f1-2)

# Update vars file
echo "Updating MongoDB version to $new_version..."
sed -i "s/mongodb_version: \"$current_version\"/mongodb_version: \"$new_version\"/" vars/mongodb_vars.yml

# Update repository if major version changed
current_major=$(echo $current_version | cut -d'.' -f1-2)
if [ "$current_major" != "$major_version" ]; then
    echo "Major version change detected. Updating repository..."
    sed -i "s/jammy\/mongodb-org\/$current_major/jammy\/mongodb-org\/$major_version/" vars/mongodb_vars.yml
    sed -i "s/server-$current_major.asc/server-$major_version.asc/" vars/mongodb_vars.yml
    sed -i "s/mongodb-org-$current_major/mongodb-org-$major_version/" vars/mongodb_vars.yml
fi

echo "Configuration updated. Running installation playbook..."

# Run the playbook
ansible-playbook -i inventory.ini mongodb_install.yml

# Check if installation was successful
if [ $? -eq 0 ]; then
    echo "====================================================="
    echo "MongoDB updated to version $new_version successfully!"
    echo "====================================================="
    echo "To verify the installation, run:"
    echo "./test_mongodb.sh"
else
    echo "====================================================="
    echo "MongoDB update failed. Please check the logs above."
    echo "====================================================="
    
    # Revert changes if update failed
    echo "Reverting to previous version..."
    sed -i "s/mongodb_version: \"$new_version\"/mongodb_version: \"$current_version\"/" vars/mongodb_vars.yml
    
    if [ "$current_major" != "$major_version" ]; then
        sed -i "s/jammy\/mongodb-org\/$major_version/jammy\/mongodb-org\/$current_major/" vars/mongodb_vars.yml
        sed -i "s/server-$major_version.asc/server-$current_major.asc/" vars/mongodb_vars.yml
        sed -i "s/mongodb-org-$major_version/mongodb-org-$current_major/" vars/mongodb_vars.yml
    fi
    
    exit 1
fi

exit 0
