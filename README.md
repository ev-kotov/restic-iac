# restic-iac

A declarative IaC of [restic](https://github.com/restic/restic) using [Podman](https://github.com/podman-container-tools/podman) (version earlier then 5).

## Requirments

- [podman-sh-lib](https://github.com/ev-kotov/podman-sh-lib)
- [notify-sh-lib](https://github.com/ev-kotov/notify-sh-lib)

## Init

```bash
sudo dnf install restic

# Create a directory for the password (system-level, not in /home)
sudo mkdir -p /etc/restic

# Generate a strong password (save it in a password manager on other machine!)
openssl rand -base64 32

# Write the password to the file
sudo sh -c 'echo "your_generated_password" > /etc/restic/pass'

# Restrict permissions on the password file
sudo chmod 600 /etc/restic/pass
sudo chown root:root /etc/restic/pass

# Get the UUID of the external disk for restic.env
sudo blkid

chmod +x deploy.sh

# Run deployment (creates the repository, installs units, enables the timer)
sh deploy.sh
```

> Important: The restic password cannot be recovered. If you lose it, all backups become useless."

## Update

Change iac and execute:

```bash
# The script safely updates systemd units and restarts the timer
sh deploy.sh
```

## Restoring data

```bash
sudo mount /dev/disk/by-label/backup /mnt/backup

# List available snapshots
sudo restic -r /mnt/backup/restic-repo --password-file /etc/restic/pass snapshots

# Restore data
sudo restic -r /mnt/backup/restic-repo --password-file /etc/restic/pass \
  restore latest --target /tmp/restore

# Restore only a specific file or directory
sudo restic -r /mnt/backup/restic-repo --password-file /etc/restic/pass \
  restore latest --target /tmp/restore --include /etc/fstab

sudo umount /mnt/backup
```
