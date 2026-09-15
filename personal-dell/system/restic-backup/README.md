# Restic Backup

Provides `restic-backup.service` systemd oneshot unit that runs `/usr/local/sbin/restic-backup` to back up this machine with [restic](https://restic.net/) to one or more targets (NAS via SFTP, Backblaze B2 via S3).

## Configuration

Create/edit configuration files:

- `/etc/restic-backup/restic-backup.env` (NOT tracked in this repo -- contains repo URLs and secrets)
- `/etc/restic-backup/password.txt` (NOT tracked in this repo -- contains restic repo password)
- `/etc/restic-backup/paths.txt` (managed via stow -- one path per line)
- `/etc/restic-backup/excludes.txt` (managed via stow -- exclude patterns)

### Required environment variables

The service loads `/etc/restic-backup/restic-backup.env` via `EnvironmentFile=`.

The script expects these variables to be set (depending on target):

- `RESTIC_TARGETS`: `nas`, `b2`, or `both` (defaults to `both`)
- `RESTIC_REPOSITORY_NAS`: repo URL for your NAS (required for `nas`/`both`)
- `RESTIC_REPOSITORY_B2`: repo URL for Backblaze B2 (required for `b2`/`both`)
- `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`: Backblaze B2 credentials (required for `b2`/`both`)

### NAS SSH client config (root)

`/root/.ssh/config` carries the `Host restic-nas` entry. It lives in the `system/setup` package and is copied, not stowed - ssh rejects a config file it does not own, so a symlink into `/home` fails with `Bad owner or permissions`.

```shell
cd ~/Documents/Projects/dotfiles/personal-dell/system/setup
sudo mkdir -p /root/.ssh
sudo cp -r root/.ssh/. /root/.ssh/
sudo chown -R root:root /root/.ssh
sudo sh -c 'chmod 700 /root/.ssh; chmod 600 /root/.ssh/config /root/.ssh/config.d/*' # glob must expand as root
```

- Put the private key at `/root/.ssh/restic-nas`
- Ensure permissions are locked down (e.g. `chmod 600 /root/.ssh/restic-nas`)

## Run

Run once manually:

```shell
sudo systemctl daemon-reload
sudo systemctl start restic-backup.service --no-block
sudo journalctl -u restic-backup.service -ef
```

Note: Initial repository setup (`restic init`) is not handled automatically -- initialize each repo ahead of time.
