#!/bin/bash

# Script to load environment variables from .env file
# Author: Cline
# Date: 2025-05-21

# Function to load environment variables from .env file
load_env() {
    ENV_FILE=".env"
    
    # Check if .env file exists
    if [ -f "$ENV_FILE" ]; then
        echo "Loading environment variables from $ENV_FILE"
        
        # Load variables from .env file
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            if [[ ! "$line" =~ ^#.*$ ]] && [[ -n "$line" ]]; then
                # Export the variable
                export "$line"
            fi
        done < "$ENV_FILE"
    else
        echo "Warning: $ENV_FILE file not found. Using default values."
        echo "You can create a .env file by copying .env.template and filling in your credentials."
    fi
}

# If this script is being sourced, load the environment variables
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    load_env
else
    # If this script is being executed directly, show usage information
    echo "This script is meant to be sourced by other scripts, not executed directly."
    echo "Usage: source load_env.sh"
    exit 1
fi
