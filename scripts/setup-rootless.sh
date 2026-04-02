#!/bin/bash
# Description: Setup Rootless environment for sysadmin user
# Usage: sudo ./setup-rootless.sh <username>

TARGET_USER=${1:-sysadmin}

echo "--- Starting Rootless Setup for $TARGET_USER ---"

# 1. 检查并开启 Linger (允许用户在离线时运行后台进程)
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Please run as root/sudo"
    exit 1
fi

echo "[1/3] Enabling linger for $TARGET_USER..."
loginctl enable-linger "$TARGET_USER"

# 2. 检查 SubUID/SubGID 配置
echo "[2/3] Checking subuid/subgid mapping..."
if grep -q "$TARGET_USER" /etc/subuid; then
    echo "SubUID mapping exists: $(grep "$TARGET_USER" /etc/subuid)"
else
    echo "Warning: No subuid mapping found. Podman might fail."
    echo "Suggested fix: usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $TARGET_USER"
fi

# 3. 设置 XDG_RUNTIME_DIR (解决 D-Bus 报错)
echo "[3/3] Configuring environment variables..."
USER_ID=$(id -u "$TARGET_USER")
BASHRC_PATH="/home/$TARGET_USER/.bashrc"

if ! grep -q "XDG_RUNTIME_DIR" "$BASHRC_PATH"; then
    echo "export XDG_RUNTIME_DIR=/run/user/$USER_ID" >> "$BASHRC_PATH"
    chown "$TARGET_USER:$TARGET_USER" "$BASHRC_PATH"
    echo "Environment variable XDG_RUNTIME_DIR added to $BASHRC_PATH"
fi

echo "--- Setup Complete! Please log in as $TARGET_USER to continue ---"
