#!/usr/bin/env bash

SERVICE_NAME="reminder"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/messager.sh" ]]; then
    echo "Error: messager not found"
    exit 1
fi

chmod +x "${SCRIPT_DIR}/messager.sh"

mkdir -p "$HOME/.config/systemd/user/"

cat >  "$HOME/.config/systemd/user/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Simple Reminder Service
After=network.target

[Service]
Type=simple
ExecStart="${SCRIPT_DIR}/messager.sh"
Restart=always
RestartSec=10

Environment=DISPLAY=:0
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID/bus

[Install]
WantedBy=default.target
EOF


systemctl --user daemon-reload
systemctl --user enable --now ${SERVICE_NAME}.service

echo "Service installed and started successfully"
