#!/bin/bash
# DD Image Deployment Script
# Sudoers: username ALL=(root) NOPASSWD: /usr/local/bin/deploy-script.sh

set -e

# Check if this is the copied version (second run)
COPIED_VERSION="${1:-}"

REPO_URL="https://github.com/andreas-schwab-swx/dd_image.git"
DEPLOY_DIR="/opt/scripts/dd_image"
TARGET_SCRIPT="/usr/local/sbin/dd_image.sh"
CONFIG_DIR="/etc/dd_image"

# First run: Update repository and self-update
if [ "$COPIED_VERSION" != "--copied" ]; then
    # Ensure base directory exists
    mkdir -p /opt/scripts

    # Clone or update repository
    if [ -d "$DEPLOY_DIR" ]; then
        cd "$DEPLOY_DIR" && git pull origin main
    else
        git clone "$REPO_URL" "$DEPLOY_DIR" && cd "$DEPLOY_DIR"
    fi

    # Overwrite self with new version and restart
    cp "$DEPLOY_DIR/deploy-script.sh" "/usr/local/bin/deploy-script.sh"
    chmod +x "/usr/local/bin/deploy-script.sh"
    chown root:root "/usr/local/bin/deploy-script.sh"

    # Restart with new version and exit silently
    exec /usr/local/bin/deploy-script.sh --copied
fi

# Second run: Perform actual deployment (copied version)
echo "Deploying dd_image.sh..."

# Secure repository directory (root access only)
chown -R root:root "$DEPLOY_DIR"
find "$DEPLOY_DIR" -type d -exec chmod 700 {} \;  # Directories: rwx------
find "$DEPLOY_DIR" -type f -exec chmod 600 {} \;  # Files: rw-------

# Set execute permissions for shell scripts in repository
find "$DEPLOY_DIR" -name "*.sh" -exec chmod +x {} \;

# Install script
cd "$DEPLOY_DIR"
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

echo "Copy erfolgreich"
