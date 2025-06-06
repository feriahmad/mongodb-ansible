#!/bin/bash

# Script to test MongoDB 8.0.9 installation using Ansible
# Author: Cline
# Date: 2025-05-21

set -e

# Display banner
echo "====================================================="
echo "MongoDB 8.0.9 Installation Test Script for Ubuntu 20.04"
echo "====================================================="

# Check if MongoDB is installed
if ! command -v mongod &> /dev/null; then
    echo "MongoDB does not appear to be installed. Please run the installation script first."
    echo "Run: ./install_mongodb.sh"
    exit 1
fi

echo "MongoDB is installed. Running test playbook..."

# Run the test playbook
ansible-playbook -i inventory.ini mongodb_test.yml

# Check if test was successful
if [ $? -eq 0 ]; then
    echo "====================================================="
    echo "MongoDB 8.0.9 test completed successfully!"
    echo "====================================================="
    echo "Your MongoDB installation is working correctly."
else
    echo "====================================================="
    echo "MongoDB test failed. Please check the logs above."
    echo "====================================================="
    exit 1
fi

exit 0
