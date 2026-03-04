# Arch Linux Reinstall Automation (niri + DMS)

Deterministic post-install automation for restoring this Arch Linux setup after a fresh install.

## Scope

This repository automates **post-install configuration only**.

It assumes:
- Arch Linux is already installed and bootable.
- A normal user with sudo access already exists.
- You can log into that user and run shell commands.

It does **not** partition disks, install the base system, or configure a bootloader.

## Default Target

- Hardware profile: `framework-7840u`
- OS: Arch Linux
- Compositor: niri
- Shell: Dank Material Shell (DMS)
- Display manager: greetd

## What the Installer Does

1. Runs preflight checks (Arch, sudo, network, required files).
2. Installs official packages from `packages/official.txt`.
3. Installs AUR packages from `packages/aur.txt`.
4. Backs up and deploys configs from `configs/`.
5. Configures system services and greetd.
6. Configures user services.
7. Applies profile hardware settings (keyboard + USB autosuspend rule).
8. Runs verification and prints pass/warn/fail summary.

## Quick Reinstall

```bash
sudo pacman -S --needed git

git clone <repo-url> ~/.config/arch-setup
cd ~/.config/arch-setup

./install.sh all
```

Then reboot:

```bash
sudo reboot
```

## CLI

```bash
./install.sh [all] [options]
./install.sh stage <name> [options]
./install.sh verify [options]
```

Options:
- `--profile <name>`: Select hardware profile (default: `framework-7840u`)
- `--dry-run`: Print planned actions without changing the system
- `--force`: Re-run completed stages in `all`
- `--no-aur`: Skip AUR stage
- `--strict-aur`: Abort when any AUR package fails
- `--log-file <path>`: Write logs to a custom path

Examples:

```bash
# Full run
./install.sh all

# Retry only config deployment
./install.sh stage 30-configs

# Verify current state only
./install.sh verify

# Full run, skip AUR
./install.sh all --no-aur
```

## Stage List

- `00-preflight`
- `10-packages-official`
- `20-packages-aur`
- `30-configs`
- `40-system-services`
- `50-user-services`
- `60-hardware`
- `90-verify`

When running `all`, completed stages are skipped by default. Use `--force` to re-run them.

## Failure Behavior

### Official packages

Missing official package entries fail the run, so broken repositories are caught early.

### AUR packages

Default behavior is continue-on-fail:
- The stage finishes.
- Failed AUR packages are recorded in `~/.local/state/arch-setup/failed-aur-packages.txt`.
- Run is marked degraded (`~/.local/state/arch-setup/degraded`).

Use `--strict-aur` if you want fail-fast behavior.

## Backups

Managed config/system files are backed up before replacement:

- Backup root: `~/.local/state/arch-setup/backups/<timestamp>/`
- Stage markers: `~/.local/state/arch-setup/stages/`
- Logs: `~/.local/state/arch-setup/install-<timestamp>.log`
- Latest log symlink: `~/.local/state/arch-setup/latest.log`

## Profiles

Profiles are in `profiles/`:

- `common.env`: shared defaults
- `framework-7840u.env`: Framework-specific overrides

### Local machine-only overrides (secrets and host-specific values)

Copy and edit:

```bash
cp configs/local/.env.example configs/local/.env
```

`configs/local/.env` is intentionally gitignored and loaded automatically during runs.

## Managed Service Targets

System services:
- `power-profiles-daemon`
- `greetd`
- `NetworkManager`
- `bluetooth`

User services:
- `pipewire`
- `pipewire-pulse`
- `wireplumber`
- `podman.socket`

## Hardware Settings (framework-7840u)

- Keyboard layout: `ca`
- Keyboard variant: `multix` (Canadian Multilingual Standard)
- USB autosuspend exception rule installed from:
  - `udev/50-usb-no-autosuspend.rules`

For immediate runtime USB fix (without reboot), use:

```bash
./scripts/apply-usb-fix.sh
```

## Repository Layout

```text
.
├── install.sh
├── README.md
├── .gitignore
├── packages/
│   ├── official.txt
│   └── aur.txt
├── profiles/
│   ├── common.env
│   └── framework-7840u.env
├── scripts/
│   ├── apply-usb-fix.sh
│   ├── lib/
│   │   └── common.sh
│   └── stages/
│       ├── 00-preflight.sh
│       ├── 10-packages-official.sh
│       ├── 20-packages-aur.sh
│       ├── 30-configs.sh
│       ├── 40-system-services.sh
│       ├── 50-user-services.sh
│       ├── 60-hardware.sh
│       └── 90-verify.sh
├── configs/
│   ├── niri/
│   ├── DankMaterialShell/
│   ├── environment.d/
│   ├── greetd/
│   │   └── config.toml
│   └── local/
│       └── .env.example
└── udev/
    └── 50-usb-no-autosuspend.rules
```

## Troubleshooting

### Re-run verify only

```bash
./install.sh verify
```

### Re-run only failed stage

```bash
./install.sh stage <stage-name>
```

### Re-run everything regardless of stage markers

```bash
./install.sh all --force
```

### Check failed AUR packages

```bash
cat ~/.local/state/arch-setup/failed-aur-packages.txt
```
