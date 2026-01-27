#!/bin/bash

# Crashpad Server Setup Script for Amazon Linux 2023
# Run this script on your EC2 instance.

set -e

# Defined constants
SERVICE_NAME="minidump-server"
SERVICE_FILE="${SERVICE_NAME}.service"
INSTALL_DIR=$(pwd)
CURRENT_USER=$(whoami)
VENV_DIR="$INSTALL_DIR/venv"

echo "Started setup for $SERVICE_NAME..."
echo "Directory: $INSTALL_DIR"
echo "User: $CURRENT_USER"

# 1. Update system and install dependencies
echo "[1/5] Installing system dependencies..."
sudo dnf update -y
sudo dnf install -y python3 python3-pip git

# 2. Setup Python Virtual Environment
echo "[2/5] Setting up Python Virtual Environment..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "Created venv."
else
    echo "venv already exists."
fi

# 3. Install Python requirements
echo "[3/5] Installing Python requirements..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo "Error: requirements.txt not found!"
    exit 1
fi

# 4. Configure and Install Systemd Service
echo "[4/5] Configuring systemd service..."

# Update key paths and user in the service file to match current install
# We create a temporary service file with the correct paths
cat > "${SERVICE_NAME}_generated.service" <<EOF
[Unit]
Description=Crashpad Receiver Server
After=network.target

[Service]
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind 0.0.0.0:5100 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Generated service file content:"
cat "${SERVICE_NAME}_generated.service"

echo "Installing service file to /etc/systemd/system/..."
sudo cp "${SERVICE_NAME}_generated.service" "/etc/systemd/system/$SERVICE_FILE"
sudo rm "${SERVICE_NAME}_generated.service"

# 5. Enable and Start Service
echo "[5/5] enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

echo "---------------------------------------------------"
echo "Setup Complete!"
echo "Check status with: sudo systemctl status $SERVICE_NAME"
echo "Logs: sudo journalctl -u $SERVICE_NAME -f"
echo "Server listening on port 5100"
echo "---------------------------------------------------"
