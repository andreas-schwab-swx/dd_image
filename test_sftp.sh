#!/bin/bash
# Simple SFTP Test Script
# This script runs on the SERVER to test SFTP functionality

set -e

# Load configuration
CONFIG_FILE="/etc/dd_image/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    echo "Please copy config.example.sh to config.sh and configure it"
    exit 1
fi

source "$CONFIG_FILE"

echo "Testing SFTP functionality on server..."
echo "Target: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"

# Test SFTP connection
echo "Testing SFTP connection..."
if ! sftp -b /dev/null "$REMOTE_USER@$REMOTE_HOST" < /dev/null; then
    echo "ERROR: Failed to connect to remote host via SFTP"
    exit 1
fi
echo "SFTP connection successful"

# Create test file
TEST_FILE="sftp-test-$(date +%s).txt"
echo "SFTP test from $(hostname) - $(date)" > "/tmp/$TEST_FILE"
echo "Test file created: /tmp/$TEST_FILE"

# Test file transfer
echo "Testing file operations..."
SFTP_COMMANDS=$(mktemp)
cat > "$SFTP_COMMANDS" << EOF
put /tmp/$TEST_FILE $REMOTE_PATH/$TEST_FILE
ls $REMOTE_PATH/$TEST_FILE
quit
EOF

echo "- Uploading test file"
echo "- Listing file"
echo "- Removing test file"

if sftp -b "$SFTP_COMMANDS" "$REMOTE_USER@$REMOTE_HOST"; then
    echo "SUCCESS: File upload/delete test successful"
else
    echo "ERROR: File operations failed"
    rm -f "$SFTP_COMMANDS" "/tmp/$TEST_FILE"
    exit 1
fi

# Cleanup
rm -f "$SFTP_COMMANDS" "/tmp/$TEST_FILE"

echo "✅ SFTP test completed successfully"
