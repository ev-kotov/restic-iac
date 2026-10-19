#!/usr/bin/env bash
set -euo pipefail

source "/home/kot/projects/podman-sh-lib/lib/podman.sh"

PROJECT_DIR="/home/kot/projects/restic-iac"

## shellcheck disable=SC1091
source "$PROJECT_DIR/restic.env" 

base_log_step "Preparing directories and files"

SYSTEMD_DIR="/etc/systemd/system"
REPO_DIR="$RESTIC_MOUNT_POINT/restic-repo"

base_log_step "Correct permissions"

chmod 700 "$PROJECT_DIR/backup-restic.sh"
chmod +x "$PROJECT_DIR/backup-restic.sh"
sudo chmod 600 "$RESTIC_PASSWORD_FILE"
sudo chown root:root "$RESTIC_PASSWORD_FILE"

base_log_step "Checking restic repository"

if [ ! -b "$RESTIC_DEVICE" ] && [ ! -L "$RESTIC_DEVICE" ]; then
    base_log_err "Device not found: $RESTIC_DEVICE"
    base_log_info "Check UUID with: sudo blkid"
    exit 1
fi

sudo mkdir -p "$RESTIC_MOUNT_POINT"
sudo mount "$RESTIC_DEVICE" "$RESTIC_MOUNT_POINT"

if [ ! -d "$REPO_DIR/config" ]; then
    base_log_info "Initializing new repository at $REPO_DIR"
    sudo mkdir -p "$REPO_DIR"

    sudo restic -r "$REPO_DIR" --password-file "$RESTIC_PASSWORD_FILE" init
    base_log_ok "Repository initialized"
else
    base_log_info "Repository already exists, skipping init"
fi

sudo umount "$RESTIC_MOUNT_POINT"
base_log_ok "Disk unmounted"

base_log_step "Installing systemd units"

# Copy, not symlink: systemd (PID 1) cannot read units from /home/* under SELinux Enforcing
sudo cp "$PROJECT_DIR/restic-backup.service" "$SYSTEMD_DIR/restic-backup.service"
sudo cp "$PROJECT_DIR/restic-backup.timer"   "$SYSTEMD_DIR/restic-backup.timer"
base_log_ok "Units copied to $SYSTEMD_DIR"

base_log_step "Reloading systemd"
sudo systemctl daemon-reload

base_log_step "Enabling timer"
sudo systemctl enable --now restic-backup.timer

base_log_step "Current status"
systemctl list-timers restic-backup.timer --no-pager

base_log_ok "Deploy completed"
base_log_info "Test backup: sudo systemctl start restic-backup.service"
base_log_info "View logs:  sudo journalctl -u restic-backup.service -f -o cat"