---
name: hetzner-nixos-install
description: Installs NixOS declaratively on Hetzner dedicated servers from rescue mode using UEFI + disko + RAID1, with preflight checks and iterative runbook updates.
---

# Hetzner NixOS Install (UEFI + disko + RAID1)

Generic runbook for bringing a fresh Hetzner dedicated server from Rescue mode to reproducible NixOS.

> Do not store host-specific secrets, keys, or personal identifiers in this skill.

## Scripts

From this skill directory:

```bash
# Gather facts on rescue host
./scripts/rescue-preflight.sh

# Run install from local machine
./scripts/install-with-nixos-anywhere.sh <target-host> <flake-attr>
```

## Local config file handling

This repo uses a committed Nix config file:
- `config.nix` (template + host configuration)

Typical fields consumed by host config:
- `hostName`
- `users = [ { name; sshKey; isSudoer; homeManagerProfile?; } ... ]`
- optional static IPv6 under `network.ipv6`
- optional Home Manager settings under `homeManager`

Edit `config.nix` for your host before install.

## Recommended workflow

1. **Preflight in rescue** (`rescue-preflight.sh`)
   - confirm UEFI, NIC, routes, disks, DNS.
2. **Prepare flake host config**
   - add `disko` module and host module.
   - keep host file sanitized if used as template.
3. **Generate hardware config during install**
   - use `--generate-hardware-config nixos-generate-config <path>`.
4. **Install with nixos-anywhere** (pure flake eval).
5. **First boot checks** (see health-check skill).
6. Commit generated hardware config and final host config.

## Known-good patterns learned in this project

- UEFI + GRUB removable install:
  - `boot.loader.grub.efiInstallAsRemovable = true;`
  - `boot.loader.efi.canTouchEfiVariables = false;` (required by NixOS assertion)
- RAID1 with disko + `boot.swraid.enable = true`.
- Set `boot.swraid.mdadmConf` with at least `MAILADDR root` to avoid mdadm monitor issues.
- Avoid hardcoding `eth0`; prefer generic DHCP bootstrap initially.
- Hetzner dedicated IPv6 may need explicit static config (`address/prefix + fe80::1 gateway`).
- Prefer non-root SSH:
  - `PermitRootLogin = "no"`
  - lock root password (`users.users.root.hashedPassword = "!"`)
  - use non-root wheel admin + passwordless sudo if desired.

## Common pitfalls

- `known_hosts` mismatch after reinstall (expected host key change).
- macOS local `nixos-rebuild` wrapper incompatibilities can happen with some channels.
  - fallback: run `nixos-rebuild` from a nix shell or execute remote rebuild directly over SSH.
- If your host config includes Linux-only Home Manager dependencies, prefer remote builds.
  - install script uses `--build-on remote` for this reason.
- First RAID sync can take time; degraded speed during initial sync is normal.

## Validation after first boot (minimum)

- `systemctl --failed`
- `cat /proc/mdstat`
- `lsblk -f`
- `ip -br addr`, `ip route`, `ip -6 route`
- `ping -c 2 1.1.1.1`, `ping -6 -c 2 2606:4700:4700::1111`
- SSH login via non-root admin user

Use `hetzner-postinstall-health-check` skill for a fuller audit.
