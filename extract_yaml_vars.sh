#!/bin/bash

# Extract simple key-value pairs from YAML file
# Usage: source extract_yaml_vars.sh <yaml_file>

if [ -z "$1" ]; then
    echo "Usage: source extract_yaml_vars.sh <yaml_file>" >&2
    return 1
fi

YAML_FILE="$1"

if [ ! -f "$YAML_FILE" ]; then
    echo "Error: YAML file '$YAML_FILE' not found" >&2
    return 1
fi

# Extract simple key-value pairs, ignoring arrays and complex structures
while IFS=': ' read -r key value; do
    # Skip empty lines, comments, and YAML document separators
    if [[ -z "$key" || "$key" =~ ^[[:space:]]*# || "$key" =~ ^[[:space:]]*--- ]]; then
        continue
    fi
    
    # Skip lines that don't look like simple key-value pairs
    if [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        continue
    fi
    
    # Remove quotes and inline comments from value
    value=$(echo "$value" | sed 's/^[[:space:]]*"\(.*\)"[[:space:]]*$/\1/' | sed 's/[[:space:]]*#.*$//')
    
    # Export the variable
    export "$key=$value"
done < <(grep -E "^[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]" "$YAML_FILE")
