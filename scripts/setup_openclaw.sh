#!/bin/bash
set -euo pipefail

# OpenClaw Setup Script
# This script sets up OpenClaw configuration files

echo "[INFO] Setting up OpenClaw..."

# Create necessary directories
mkdir -p /root/.openclaw/agents/main/agent
mkdir -p /workspace/openclaw/logs

# Copy configuration files if they exist
if [ -f /workspace/config/openclaw.json ]; then
    cp /workspace/config/openclaw.json /root/.openclaw/openclaw.json
    echo "[INFO] Copied openclaw.json"
fi

if [ -f /workspace/config/auth-profiles.json ]; then
    cp /workspace/config/auth-profiles.json /root/.openclaw/agents/main/agent/auth-profiles.json
    echo "[INFO] Copied auth-profiles.json"
fi

# Set permissions
chmod -R 755 /root/.openclaw

echo "[INFO] OpenClaw setup completed!"
