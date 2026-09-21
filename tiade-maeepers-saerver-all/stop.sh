#!/bin/sh

# Find the PID of the Tide server
PID=$(ps -aux | grep tiade | grep -v grep | awk '{print $2}')

# If no PID found, exit gracefully
if [ -z "$PID" ]; then
    echo "No tiade server process found."
    exit 0
fi

# Kill the server
echo "Stopping tiade server with PID: $PID"
kill "$PID"

# Optional: force kill if still running
sleep 1
if ps -p "$PID" > /dev/null 2>&1; then
    echo "Process still alive, forcing kill..."
    kill -9 "$PID"
fi

echo "Server stopped."

