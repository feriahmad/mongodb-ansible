#!/bin/bash

# Script to monitor MongoDB performance
# Author: Cline
# Date: 2025-05-21

set -e

# Load environment variables from .env file
source ./load_env.sh

# Display banner
echo "====================================================="
echo "MongoDB Performance Monitoring Script"
echo "====================================================="

# Default values
INTERVAL=5
COUNT=10
ADMIN_USER="${MONGODB_ADMIN_USER:-}"
ADMIN_PASS="${MONGODB_ADMIN_PASS:-}"
OUTPUT_FORMAT="console"
OUTPUT_FILE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --interval)
        INTERVAL="$2"
        shift
        shift
        ;;
        --count)
        COUNT="$2"
        shift
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
        --output)
        OUTPUT_FORMAT="$2"
        shift
        shift
        ;;
        --file)
        OUTPUT_FILE="$2"
        shift
        shift
        ;;
        --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --interval SECONDS   Interval between checks in seconds (default: 5)"
        echo "  --count NUMBER       Number of checks to perform (default: 10)"
        echo "  --admin-user USER    Admin username for authentication"
        echo "  --admin-pass PASS    Admin password for authentication"
        echo "  --output FORMAT      Output format: console, json, csv (default: console)"
        echo "  --file PATH          Output file path (if not specified, output to console)"
        echo "  --help               Show this help message"
        exit 0
        ;;
        *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
done

# Validate interval and count
if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]]; then
    echo "Error: Interval must be a positive integer"
    exit 1
fi

if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
    echo "Error: Count must be a positive integer"
    exit 1
fi

# Validate output format
if [[ "$OUTPUT_FORMAT" != "console" && "$OUTPUT_FORMAT" != "json" && "$OUTPUT_FORMAT" != "csv" ]]; then
    echo "Error: Output format must be one of: console, json, csv"
    exit 1
fi

# Prepare authentication string
AUTH_STRING=""
if [ -n "$ADMIN_USER" ] && [ -n "$ADMIN_PASS" ]; then
    AUTH_STRING="--authenticationDatabase admin -u $ADMIN_USER -p $ADMIN_PASS"
fi

# Create Ansible playbook for monitoring
cat > mongodb_monitor.yml << EOF
---
- name: Monitor MongoDB Performance
  hosts: mongodb
  become: yes
  vars_files:
    - vars/mongodb_vars.yml
  vars:
    interval: ${INTERVAL}
    count: ${COUNT}
    output_format: "${OUTPUT_FORMAT}"
    output_file: "${OUTPUT_FILE}"
    auth_string: "${AUTH_STRING}"
  tasks:
    - name: Check if MongoDB is running
      command: systemctl status {{ mongodb_service_name }}
      register: service_status
      changed_when: false
      ignore_errors: yes

    - name: Fail if MongoDB is not running
      fail:
        msg: "MongoDB is not running. Please start the service first."
      when: service_status.rc != 0

    - name: Create monitoring script
      copy:
        dest: /tmp/mongodb_monitor.js
        content: |
          // MongoDB Performance Monitoring Script
          var stats = [];
          var startTime = new Date();
          
          // Function to collect stats
          function collectStats() {
            var serverStatus = db.serverStatus();
            var connPoolStats = db.adminCommand({ connPoolStats: 1 });
            var dbStats = {};
            
            // Get stats for each database
            var dbs = db.adminCommand({ listDatabases: 1 }).databases;
            dbs.forEach(function(database) {
              if (database.name !== "admin" && database.name !== "config" && database.name !== "local") {
                dbStats[database.name] = db.getSiblingDB(database.name).stats();
              }
            });
            
            // Collect relevant metrics
            var stat = {
              timestamp: new Date(),
              connections: {
                current: serverStatus.connections.current,
                available: serverStatus.connections.available,
                totalCreated: serverStatus.connections.totalCreated
              },
              memory: {
                resident: serverStatus.mem.resident,
                virtual: serverStatus.mem.virtual,
                mapped: serverStatus.mem.mapped
              },
              network: {
                bytesIn: serverStatus.network.bytesIn,
                bytesOut: serverStatus.network.bytesOut,
                numRequests: serverStatus.network.numRequests
              },
              opcounters: {
                insert: serverStatus.opcounters.insert,
                query: serverStatus.opcounters.query,
                update: serverStatus.opcounters.update,
                delete: serverStatus.opcounters.delete,
                getmore: serverStatus.opcounters.getmore,
                command: serverStatus.opcounters.command
              },
              globalLock: {
                totalTime: serverStatus.globalLock.totalTime,
                currentQueue: {
                  total: serverStatus.globalLock.currentQueue.total,
                  readers: serverStatus.globalLock.currentQueue.readers,
                  writers: serverStatus.globalLock.currentQueue.writers
                }
              },
              dbStats: dbStats
            };
            
            stats.push(stat);
            return stat;
          }
          
          // Function to print stats in console format
          function printConsoleStats(stat) {
            print("===================================================");
            print("Timestamp: " + stat.timestamp);
            print("===================================================");
            print("Connections: current=" + stat.connections.current + 
                  ", available=" + stat.connections.available + 
                  ", totalCreated=" + stat.connections.totalCreated);
            print("Memory (MB): resident=" + stat.memory.resident + 
                  ", virtual=" + stat.memory.virtual + 
                  ", mapped=" + (stat.memory.mapped || "N/A"));
            print("Network: bytesIn=" + stat.network.bytesIn + 
                  ", bytesOut=" + stat.network.bytesOut + 
                  ", numRequests=" + stat.network.numRequests);
            print("Operations: insert=" + stat.opcounters.insert + 
                  ", query=" + stat.opcounters.query + 
                  ", update=" + stat.opcounters.update + 
                  ", delete=" + stat.opcounters.delete + 
                  ", getmore=" + stat.opcounters.getmore + 
                  ", command=" + stat.opcounters.command);
            print("Global Lock Queue: total=" + stat.globalLock.currentQueue.total + 
                  ", readers=" + stat.globalLock.currentQueue.readers + 
                  ", writers=" + stat.globalLock.currentQueue.writers);
            
            print("Database Stats:");
            for (var dbName in stat.dbStats) {
              var dbStat = stat.dbStats[dbName];
              print("  " + dbName + ": collections=" + dbStat.collections + 
                    ", objects=" + dbStat.objects + 
                    ", dataSize=" + (dbStat.dataSize / (1024*1024)).toFixed(2) + " MB");
            }
            print("");
          }
          
          // Function to convert stats to CSV
          function statsToCSV() {
            var header = "timestamp,connections.current,connections.available,connections.totalCreated," +
                         "memory.resident,memory.virtual,memory.mapped," +
                         "network.bytesIn,network.bytesOut,network.numRequests," +
                         "opcounters.insert,opcounters.query,opcounters.update,opcounters.delete,opcounters.getmore,opcounters.command," +
                         "globalLock.currentQueue.total,globalLock.currentQueue.readers,globalLock.currentQueue.writers";
            
            var csv = [header];
            
            stats.forEach(function(stat) {
              var row = [
                stat.timestamp,
                stat.connections.current,
                stat.connections.available,
                stat.connections.totalCreated,
                stat.memory.resident,
                stat.memory.virtual,
                stat.memory.mapped || "N/A",
                stat.network.bytesIn,
                stat.network.bytesOut,
                stat.network.numRequests,
                stat.opcounters.insert,
                stat.opcounters.query,
                stat.opcounters.update,
                stat.opcounters.delete,
                stat.opcounters.getmore,
                stat.opcounters.command,
                stat.globalLock.currentQueue.total,
                stat.globalLock.currentQueue.readers,
                stat.globalLock.currentQueue.writers
              ].join(",");
              
              csv.push(row);
            });
            
            return csv.join("\\n");
          }
          
          // Main monitoring loop
          print("Starting MongoDB performance monitoring...");
          print("Interval: ${INTERVAL} seconds, Count: ${COUNT}");
          print("");
          
          for (var i = 0; i < ${COUNT}; i++) {
            var stat = collectStats();
            
            if ("${OUTPUT_FORMAT}" === "console") {
              printConsoleStats(stat);
            }
            
            if (i < ${COUNT} - 1) {
              sleep(${INTERVAL} * 1000);
            }
          }
          
          // Output results based on format
          if ("${OUTPUT_FORMAT}" === "json") {
            print(JSON.stringify(stats, null, 2));
          } else if ("${OUTPUT_FORMAT}" === "csv") {
            print(statsToCSV());
          }
          
          var endTime = new Date();
          var duration = (endTime - startTime) / 1000;
          
          print("===================================================");
          print("MongoDB monitoring completed.");
          print("Total duration: " + duration + " seconds");
          print("Samples collected: " + stats.length);
          print("===================================================");

    - name: Run monitoring script
      shell: >
        mongosh {{ auth_string }} --quiet /tmp/mongodb_monitor.js {% if output_file %} > {{ output_file }} {% endif %}
      register: monitor_result
      changed_when: false

    - name: Display monitoring results
      debug:
        msg: "{{ monitor_result.stdout_lines }}"
      when: output_file == ""

    - name: Clean up monitoring script
      file:
        path: /tmp/mongodb_monitor.js
        state: absent
EOF

# Run the monitoring playbook
echo "Starting MongoDB performance monitoring..."
echo "Interval: $INTERVAL seconds, Count: $COUNT"
if [ -n "$OUTPUT_FILE" ]; then
    echo "Output will be saved to: $OUTPUT_FILE"
else
    echo "Output will be displayed on console"
fi
echo

ansible-playbook -i inventory.ini mongodb_monitor.yml

# Check if monitoring was successful
if [ $? -eq 0 ]; then
    echo "====================================================="
    echo "MongoDB performance monitoring completed successfully!"
    echo "====================================================="
    
    if [ -n "$OUTPUT_FILE" ]; then
        echo "Results saved to: $OUTPUT_FILE"
    fi
    
    # Clean up playbook
    rm mongodb_monitor.yml
else
    echo "====================================================="
    echo "MongoDB performance monitoring failed. Please check the logs above."
    echo "====================================================="
    rm mongodb_monitor.yml
    exit 1
fi

exit 0
