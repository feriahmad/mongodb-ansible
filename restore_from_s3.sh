#!/bin/bash

# Script to restore MongoDB database from S3 backup
# This script downloads a backup from S3, extracts it, and restores it to MongoDB

# Load environment variables from .env file
source ./load_env.sh

# Set HOME directory
export HOME=/home/ubuntu/

# MongoDB host
HOST=localhost

# DB name
DBNAME=${MONGODB_RESTORE_DB}

# S3 bucket name
BUCKET=${S3_BUCKET}

# Linux user account
USER=ubuntu

# MongoDB credentials
USERNAME=${MONGODB_RESTORE_USER}
PASSWORD=${MONGODB_RESTORE_PASS}

# AWS credentials
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

# Check if required environment variables are set
check_env_vars() {
    local missing=false
    
    if [ -z "$MONGODB_RESTORE_USER" ]; then
        echo "Error: MONGODB_RESTORE_USER is not set in .env file"
        missing=true
    fi
    
    if [ -z "$MONGODB_RESTORE_PASS" ]; then
        echo "Error: MONGODB_RESTORE_PASS is not set in .env file"
        missing=true
    fi
    
    if [ -z "$MONGODB_RESTORE_DB" ]; then
        echo "Error: MONGODB_RESTORE_DB is not set in .env file"
        missing=true
    fi
    
    if [ -z "$S3_BUCKET" ]; then
        echo "Error: S3_BUCKET is not set in .env file"
        missing=true
    fi
    
    if [ -z "$AWS_ACCESS_KEY_ID" ]; then
        echo "Error: AWS_ACCESS_KEY_ID is not set in .env file"
        missing=true
    fi
    
    if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "Error: AWS_SECRET_ACCESS_KEY is not set in .env file"
        missing=true
    fi
    
    if [ -z "$AWS_DEFAULT_REGION" ]; then
        echo "Error: AWS_DEFAULT_REGION is not set in .env file"
        missing=true
    fi
    
    if [ "$missing" = true ]; then
        echo "Please set all required environment variables in the .env file"
        echo "You can create a .env file by copying .env.template and filling in your credentials"
        exit 1
    fi
}

# Check environment variables
check_env_vars

# Backup directory
DEST=/data/backup/tmp

# Display usage information
function show_usage {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --backup FILENAME   Specify the backup filename in S3 (required)"
    echo "  --drop              Drop existing collections before restoring"
    echo "  --aws-key KEY       AWS access key ID"
    echo "  --aws-secret SECRET AWS secret access key"
    echo "  --aws-region REGION AWS region (default: ap-southeast-1)"
    echo "  --help              Show this help message"
    echo ""
    echo "Example: $0 --backup pajak-prod-2025-07-24-15:30:45.tar --aws-key YOUR_KEY --aws-secret YOUR_SECRET"
    exit 1
}

# Parse command line arguments
DROP_EXISTING=false
BACKUP_FILENAME=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --backup)
        BACKUP_FILENAME="$2"
        shift
        shift
        ;;
        --drop)
        DROP_EXISTING=true
        shift
        ;;
        --aws-key)
        AWS_ACCESS_KEY_ID="$2"
        shift
        shift
        ;;
        --aws-secret)
        AWS_SECRET_ACCESS_KEY="$2"
        shift
        shift
        ;;
        --aws-region)
        AWS_DEFAULT_REGION="$2"
        shift
        shift
        ;;
        --help)
        show_usage
        ;;
        *)
        echo "Unknown option: $1"
        show_usage
        ;;
    esac
done

# Check if backup filename is provided
if [ -z "$BACKUP_FILENAME" ]; then
    echo "Error: Backup filename is required"
    show_usage
fi

# Create backup directory if it doesn't exist
/bin/mkdir -p $DEST

# Log
echo "====================================================="
echo "MongoDB Restore from S3"
echo "====================================================="
echo "Downloading backup $BACKUP_FILENAME from s3://$BUCKET/"
echo "Target database: $HOST/$DBNAME"
if [ "$DROP_EXISTING" = true ]; then
    echo "Warning: Existing collections will be dropped before restore"
fi
echo "====================================================="

# Download tar from S3
echo "Step 1: Downloading backup from S3..."

# Export AWS credentials for the aws command
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION

/usr/local/bin/aws s3 cp s3://$BUCKET/$BACKUP_FILENAME $DEST/../$BACKUP_FILENAME

if [ $? -ne 0 ]; then
    echo "Error: Failed to download backup from S3"
    /bin/rm -rf $DEST
    exit 1
fi

# Extract tar file
echo "Step 2: Extracting backup..."
/bin/tar xf $DEST/../$BACKUP_FILENAME -C $DEST

if [ $? -ne 0 ]; then
    echo "Error: Failed to extract backup"
    /bin/rm -f $DEST/../$BACKUP_FILENAME
    /bin/rm -rf $DEST
    exit 1
fi

# Restore from MongoDB dump
echo "Step 3: Restoring database..."
if [ "$DROP_EXISTING" = true ]; then
    /usr/bin/mongorestore -h $HOST -u $USERNAME -p $PASSWORD -d $DBNAME --drop $DEST/$DBNAME
else
    /usr/bin/mongorestore -h $HOST -u $USERNAME -p $PASSWORD -d $DBNAME $DEST/$DBNAME
fi

if [ $? -ne 0 ]; then
    echo "Error: Failed to restore database"
    /bin/rm -f $DEST/../$BACKUP_FILENAME
    /bin/rm -rf $DEST
    exit 1
fi

# Clean up
echo "Step 4: Cleaning up..."
/bin/rm -f $DEST/../$BACKUP_FILENAME
/bin/rm -rf $DEST

# All done
echo "====================================================="
echo "Restore completed successfully!"
echo "Database $DBNAME has been restored from $BACKUP_FILENAME"
echo "====================================================="

exit 0
