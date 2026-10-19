#!/usr/bin/env bash
set -euo pipefail

# $HOME = /root
source "/home/kot/projects/podman-sh-lib/lib/podman.sh"
source "/home/kot/projects/notify-sh-lib/lib/email.sh"

PROJ_DIR="/home/kot/projects/restic-iac"

# shellcheck disable=SC1091
source "$PROJ_DIR/restic.env"

base_log_step "Checking base variables"

if [ ! -b "$RESTIC_DEVICE" ] && [ ! -L "$RESTIC_DEVICE" ]; then
    base_log_err "Device not found: $RESTIC_DEVICE or not symlink"
    exit 1
fi

if [ ! -f "$RESTIC_PASSWORD_FILE" ]; then
    base_log_err "Password file not found: $RESTIC_PASSWORD_FILE"
    exit 1
fi

if [ ! -f "$RESTIC_EXCLUDE_FILE" ]; then
    base_log_err "Exclude file not found: $RESTIC_EXCLUDE_FILE"
    exit 1
fi

base_log_step "Checking dump markers"
STALE=0

podman_marker_check "/srv/immich-data/backups/.last-dump-is-ok" "Immich" "$RESTIC_MARKER_MAX_HOURS" || STALE=1
podman_marker_check "/srv/forgejo-data/backups/.last-dump-is-ok" "Forgejo" "$RESTIC_MARKER_MAX_HOURS" || STALE=1
podman_marker_check "/srv/seafile-data/backups/.last-dump-is-ok" "Seafile" "$RESTIC_MARKER_MAX_HOURS" || STALE=1

if [ "$STALE" -eq 1 ]; then
    base_log_warn "Some dumps are stale. Proceeding with backup anyway"
fi

base_log_step "Preparing directories and files"
mkdir -p "$RESTIC_MOUNT_POINT"

base_log_step "Mount"
base_log_info "Mounting $RESTIC_DEVICE at $RESTIC_MOUNT_POINT"
mount "$RESTIC_DEVICE" "$RESTIC_MOUNT_POINT"

trap 'base_log_info "Ensure unmount on any exit. Fallback to lazy unmount if busy..."; umount "$RESTIC_MOUNT_POINT" 2>/dev/null || umount -l "$RESTIC_MOUNT_POINT" 2>/dev/null || true' EXIT

base_log_step "Run backup and rotation"
base_log_info "Running restic backup"

read -r -a PATHS_ARRAY <<< "$RESTIC_BACKUP_PATHS" || true

if [ ${#PATHS_ARRAY[@]} -eq 0 ]; then
    base_log_err "No backup paths specified in RESTIC_BACKUP_PATHS"
    exit 1
fi

base_log_info "Run debug"

if restic backup \
    -r "$RESTIC_REPOSITORY" \
    --password-file "$RESTIC_PASSWORD_FILE" \
    --exclude-file "$RESTIC_EXCLUDE_FILE" \
    --exclude-caches \
    --tag automated \
    "${PATHS_ARRAY[@]}"; then
    BACKUP_STATUS="OK"
else
    BACKUP_STATUS="FAILED"
fi


if [ "$BACKUP_STATUS" = "OK" ]; then
    base_log_info "Rotation"
    base_log_info "Forgetting old snapshots"
    restic forget \
        -r "$RESTIC_REPOSITORY" \
        --password-file "$RESTIC_PASSWORD_FILE" \
        --keep-daily "$RESTIC_KEEP_DAILY" \
        --keep-weekly "$RESTIC_KEEP_WEEKLY" \
        --keep-monthly "$RESTIC_KEEP_MONTHLY" \
        --prune
fi

base_log_step "Notification"

if [ "$BACKUP_STATUS" = "OK" ]; then
    MSG="Restic backup completed and saved to $RESTIC_REPOSITORY on $(hostname) at $(date)"
    email_send "$EMAIL_RECIPIENT" "Systemd notify - restic backup" "$MSG"
    base_log_ok "$MSG"
else
    MSG="Restic backup FAILED and on $(hostname) at $(date). Check journalctl"
    email_send "$EMAIL_RECIPIENT" "[FAILED] Systemd notify - restic backup" "$MSG"
    base_log_err "$MSG"
    exit 1
fi