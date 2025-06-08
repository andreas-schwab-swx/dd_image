#!/bin/bash
# DD Image Deployment Script
# Place at: /usr/local/bin/deploy-dd-image.sh
# Sudoers: username ALL=(root) NOPASSWD: /usr/local/bin/deploy-dd-image.sh

set -e

REPO_URL="https://github.com/andreas-schwab-swx/dd_image.git"
DEPLOY_DIR="/opt/scripts/dd_image"
TARGET_SCRIPT="/usr/local/sbin/dd_image.sh"

echo "Deploying dd_image.sh..."

# Ensure base directory exists
mkdir -p /opt/scripts

# Clone or update repository
if [ -d "$DEPLOY_DIR" ]; then
    cd "$DEPLOY_DIR" && git pull origin main
else
    git clone "$REPO_URL" "$DEPLOY_DIR" && cd "$DEPLOY_DIR"
fi

# Install script
cp dd_image.sh "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"
chown root:root "$TARGET_SCRIPT"

echo "Deployment completed: $TARGET_SCRIPT"
