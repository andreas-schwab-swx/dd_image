#!/bin/bash
# DD Image Deployment Script
# Place at: /usr/local/bin/deploy-dd-image.sh
# Sudoers: username ALL=(root) NOPASSWD: /usr/local/bin/deploy-dd-image.sh

set -e

REPO_URL="https://github.com/andreas-schwab-swx/dd_image.git"
DEPLOY_DIR="/opt/scripts/dd_image"
TARGET_SCRIPT="/usr/local/sbin/dd_image.sh"
CONFIG_DIR="/etc/dd_image"

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

# Install configuration (only if config.sh exists)
mkdir -p "$CONFIG_DIR"
if [ -f "config.sh" ]; then
    cp config.sh "$CONFIG_DIR/"
    chmod 600 "$CONFIG_DIR/config.sh"
    chown root:root "$CONFIG_DIR/config.sh"
    echo "Configuration installed: $CONFIG_DIR/config.sh"
else
    echo "No config.sh found - copy config.example.sh to config.sh and configure"
fi

echo "Deployment completed: $TARGET_SCRIPT"
