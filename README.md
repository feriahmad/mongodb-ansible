# MongoDB 8.0.9 Installation Ansible Playbook

This Ansible playbook automates the installation of MongoDB 8.0.9 on Ubuntu 20.04.

## Prerequisites

- Ubuntu 20.04 target system
- Ansible installed on the control machine
- Sudo privileges on the target system

## Project Structure

- `inventory.ini`: Contains the target hosts (localhost in this case)
- `mongodb_install.yml`: The main playbook that installs MongoDB 8.0.9
- `mongodb_test.yml`: A playbook to test the MongoDB installation
- `vars/mongodb_vars.yml`: Contains configurable variables for MongoDB installation
- `templates/mongod.conf.j2`: Template for MongoDB configuration file
- `.env.template`: Template for environment variables (copy to .env and customize)
- `load_env.sh`: Script to load environment variables from .env file
- Various utility scripts for managing MongoDB (see [Utility Scripts Summary](#utility-scripts-summary))

## Usage

### Using the Installation Script

The easiest way to install MongoDB is to use the provided installation script:

```bash
./install_mongodb.sh
```

This script will:
1. Check if Ansible is installed and install it if necessary
2. Run the MongoDB installation playbook
3. Provide instructions for verifying the installation

### Manual Installation

Alternatively, you can run the playbook directly:

```bash
ansible-playbook -i inventory.ini mongodb_install.yml
```

To customize the MongoDB installation, modify the variables in `vars/mongodb_vars.yml` before running the playbook.

## What the Playbook Does

1. Adds the MongoDB GPG key
2. Adds the MongoDB 8.0 repository
3. Updates apt cache
4. Installs MongoDB 8.0.9 packages
5. Creates necessary directories for MongoDB data and logs
6. Pins the MongoDB version to prevent accidental upgrades
7. Configures MongoDB using the template
8. Enables and starts the MongoDB service
9. Verifies the MongoDB installation by checking the version

> **Note**: The order of tasks is important. The MongoDB packages must be installed before creating the data and log directories with the mongodb user as owner, since the mongodb user is created during package installation.
>
> **Important**: This playbook includes a custom systemd service file for MongoDB to ensure proper startup. The configuration also sets `fork: false` in the MongoDB configuration file, which is required for proper operation with systemd.

## Verification

### Using the Status Script

The easiest way to check the status of your MongoDB installation is to use the provided status script:

```bash
./mongodb_status.sh
```

This script will provide a comprehensive overview of your MongoDB installation, including:
- Installation status and version
- Service status (running or stopped)
- Configuration details (port, bind IP, data directory, etc.)
- Server status information
- List of databases
- Connection information

### Manual Verification

You can also verify manually by:

1. Checking the service status:
   ```bash
   systemctl status mongod
   ```

2. Connecting to MongoDB:
   ```bash
   mongosh
   ```

3. Checking the MongoDB version:
   ```bash
   mongod --version
   ```

### Using the Test Script

To verify your MongoDB installation, you can use the provided test script:

```bash
./test_mongodb.sh
```

This script will:
1. Check if MongoDB is installed
2. Run the test playbook
3. Report on the success or failure of the tests

### Manual Testing

Alternatively, you can run the test playbook directly:

```bash
ansible-playbook -i inventory.ini mongodb_test.yml
```

The test playbook will:
- Check if the MongoDB service is running
- Verify the MongoDB version
- Test the connection to MongoDB
- Create a test database and collection
- Insert a test document and retrieve it

## Configuration

### Ansible Variables

Basic configuration parameters can be modified in the `vars/mongodb_vars.yml` file:

- MongoDB version: 8.0.9
- MongoDB port: 27017
- Bind IP: 127.0.0.1 (localhost only)
- Data directory: /var/lib/mongodb
- Log directory: /var/log/mongodb
- Configuration file: /etc/mongod.conf

### Environment Variables

For sensitive information like admin credentials, you can use environment variables. This project includes a `.env.template` file that you can copy to `.env` and customize:

```bash
cp .env.template .env
```

Then edit the `.env` file to set your credentials:

```
# MongoDB Environment Variables
MONGODB_ADMIN_USER=admin
MONGODB_ADMIN_PASS=your_secure_password_here
MONGODB_PORT=27017
MONGODB_BIND_IP=127.0.0.1
MONGODB_BACKUP_DIR=/tmp/mongodb_backups
```

The `.env` file is loaded by the utility scripts to access these environment variables. This approach keeps sensitive information like passwords out of your repository, as the `.env` file is included in `.gitignore`.

The following scripts use environment variables from the `.env` file:
- `secure_mongodb.sh`: Uses admin credentials for setting up authentication
- `manage_users.sh`: Uses admin credentials for user management operations
- `monitor_mongodb.sh`: Uses admin credentials for monitoring (if authentication is enabled)
- `backup_mongodb.sh`: Uses backup directory and admin credentials
- `restore_mongodb.sh`: Uses admin credentials for restore operations (if authentication is enabled)

## Backing Up MongoDB

To create backups of your MongoDB databases, you can use the provided backup script:

```bash
./backup_mongodb.sh
```

By default, this script will back up all databases to `/tmp/mongodb_backups/[timestamp]`.

You can customize the backup with the following options:
- `--dir PATH`: Specify a custom backup directory
- `--db NAME`: Backup only a specific database
- `--help`: Show usage information

Example:
```bash
./backup_mongodb.sh --dir /home/user/mongodb_backups --db myapp
```

The backup script will:
1. Create a timestamped backup directory
2. Get a list of all databases (or use the specified database)
3. Use mongodump to create compressed backups
4. Create a backup info file with details about the backup

### Restoring from Backup

To restore MongoDB databases from a backup, you can use the provided restore script:

```bash
./restore_mongodb.sh --path /path/to/backup
```

The restore script supports the following options:
- `--path PATH`: Specify the backup directory path (required)
- `--db NAME`: Restore only a specific database
- `--drop`: Drop existing collections before restoring
- `--help`: Show usage information

Example:
```bash
./restore_mongodb.sh --path /tmp/mongodb_backups/20250521_120000 --db myapp --drop
```

The restore script will:
1. Verify the backup directory exists
2. Display information about the backup
3. Restore the databases using mongorestore
4. Report on the success or failure of the restore operation

## Updating MongoDB

To update MongoDB to a newer version, you can use the provided update script:

```bash
./update_mongodb.sh
```

This script will:
1. Show the current MongoDB version
2. Ask for the new version you want to install
3. Update the configuration files
4. Run the installation playbook with the new version
5. Automatically revert changes if the update fails

The script handles both minor version updates (e.g., 8.0.9 to 8.0.10) and major version updates (e.g., 8.0.9 to 9.0.0) by updating the repository information as needed.

## Uninstallation

If you need to remove MongoDB from your system, you can use the provided uninstall script:

```bash
./uninstall_mongodb.sh
```

This script will:
1. Ask for confirmation before proceeding
2. Stop the MongoDB service
3. Remove all MongoDB packages
4. Remove the MongoDB repository and GPG key
5. Delete MongoDB data and log directories
6. Clean up the system

**Warning**: This will completely remove MongoDB and all its data from your system. Make sure you have a backup of any important data before running this script.

## Securing MongoDB

### Basic Security Configuration

To secure your MongoDB installation, you can use the provided security script:

```bash
./secure_mongodb.sh
```

By default, this script will:
1. Enable authentication
2. Create an admin user with full privileges
3. Configure MongoDB to only accept connections from localhost (127.0.0.1)

You can customize the security settings with the following options:
- `--no-auth`: Disable authentication
- `--admin-user USER`: Set admin username (will prompt if not provided)
- `--admin-pass PASS`: Set admin password (will prompt if not provided)
- `--enable-tls`: Enable TLS/SSL for encrypted connections
- `--bind-ip IP`: Set bind IP address (default: 127.0.0.1)
- `--help`: Show usage information

Example:
```bash
./secure_mongodb.sh --admin-user admin --bind-ip 0.0.0.0
```

After running the script, you'll need to authenticate when connecting to MongoDB:
```bash
mongosh --authenticationDatabase admin -u <username> -p <password>
```

### User Management

Once you've secured your MongoDB installation with authentication, you can use the user management script to create, delete, and list users:

```bash
./manage_users.sh
```

The script supports the following actions:

1. Creating a new user:
```bash
./manage_users.sh --create --username myuser --password mypass --database mydb --roles readWrite,dbAdmin --admin-user admin --admin-pass adminpass
```

2. Deleting a user:
```bash
./manage_users.sh --delete --username myuser --database mydb --admin-user admin --admin-pass adminpass
```

3. Listing all users:
```bash
./manage_users.sh --list --admin-user admin --admin-pass adminpass
```

Available options:
- `--create`: Create a new user
- `--delete`: Delete an existing user
- `--list`: List all users
- `--username USER`: Username for the operation
- `--password PASS`: Password for the new user
- `--database DB`: Database for the user (default: admin)
- `--roles ROLES`: Comma-separated list of roles (e.g., readWrite,dbAdmin)
- `--admin-user USER`: Admin username for authentication
- `--admin-pass PASS`: Admin password for authentication
- `--help`: Show usage information

Common MongoDB roles include:
- `read`: Read-only access to a database
- `readWrite`: Read and write access to a database
- `dbAdmin`: Database administration tasks
- `userAdmin`: User administration for a database
- `clusterAdmin`: Cluster administration tasks
- `readAnyDatabase`: Read-only access to all databases
- `readWriteAnyDatabase`: Read and write access to all databases
- `userAdminAnyDatabase`: User administration for all databases
- `dbAdminAnyDatabase`: Database administration for all databases

## Performance Monitoring

To monitor the performance of your MongoDB installation, you can use the provided monitoring script:

```bash
./monitor_mongodb.sh
```

By default, this script will collect performance metrics every 5 seconds for a total of 10 samples and display them on the console.

You can customize the monitoring with the following options:
- `--interval SECONDS`: Interval between checks in seconds (default: 5)
- `--count NUMBER`: Number of checks to perform (default: 10)
- `--admin-user USER`: Admin username for authentication (if authentication is enabled)
- `--admin-pass PASS`: Admin password for authentication (if authentication is enabled)
- `--output FORMAT`: Output format: console, json, csv (default: console)
- `--file PATH`: Output file path (if not specified, output to console)
- `--help`: Show usage information

Example:
```bash
./monitor_mongodb.sh --interval 10 --count 30 --output csv --file mongodb_metrics.csv
```

The monitoring script collects the following metrics:
- Connection statistics (current, available, total created)
- Memory usage (resident, virtual, mapped)
- Network traffic (bytes in/out, number of requests)
- Operation counters (insert, query, update, delete, getmore, command)
- Global lock queue (total, readers, writers)
- Database statistics (collections, objects, data size)

This information can be useful for:
- Identifying performance bottlenecks
- Monitoring resource usage
- Capacity planning
- Troubleshooting issues

## Utility Scripts Summary

This project includes several utility scripts to help you manage your MongoDB installation:

| Script | Description | Usage |
|--------|-------------|-------|
| `install_mongodb.sh` | Installs MongoDB 8.0.9 | `./install_mongodb.sh` |
| `mongodb_status.sh` | Checks the status of MongoDB | `./mongodb_status.sh` |
| `test_mongodb.sh` | Tests the MongoDB installation | `./test_mongodb.sh` |
| `backup_mongodb.sh` | Creates a backup of MongoDB databases | `./backup_mongodb.sh [options]` |
| `restore_mongodb.sh` | Restores MongoDB from a backup | `./restore_mongodb.sh --path /path/to/backup [options]` |
| `update_mongodb.sh` | Updates MongoDB to a newer version | `./update_mongodb.sh` |
| `uninstall_mongodb.sh` | Removes MongoDB from the system | `./uninstall_mongodb.sh` |
| `secure_mongodb.sh` | Configures security settings for MongoDB | `./secure_mongodb.sh [options]` |
| `manage_users.sh` | Creates, deletes, and lists MongoDB users | `./manage_users.sh --action [options]` |
| `monitor_mongodb.sh` | Monitors MongoDB performance metrics | `./monitor_mongodb.sh [options]` |

All scripts are designed to work together and provide a complete solution for managing MongoDB on Ubuntu 20.04.
