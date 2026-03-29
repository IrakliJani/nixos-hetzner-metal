---
name: hetzner-postinstall-health-check
description: Runs post-install health checks on a NixOS Hetzner server (systemd failures, RAID, mounts, network, SSH, firewall, time, DNS, optional EFI and SMART). Use immediately after first boot and after major changes.
---

# Hetzner Post-Install Health Check

Run this after first boot or after major config changes.

## Script

From this skill directory:

```bash
./scripts/postinstall-health-check.sh
```

## Usage examples

Local run on server:
```bash
./scripts/postinstall-health-check.sh
```

Force interface and skip SMART:
```bash
./scripts/postinstall-health-check.sh --iface enp6s0 --no-smart
```

## What it checks

- rebuild dry-run (`nixos-rebuild dry-run`)
- failed units
- boot errors (journal)
- RAID status (`/proc/mdstat`, `mdadm --detail`)
- block devices and boot mounts
- IPv4/IPv6 addresses/routes
- IPv4/IPv6 reachability
- SSH listener
- time sync
- DNS resolution
- firewall rules (nftables)
- optional EFI boot entries (`efibootmgr`)
- optional SMART health for NVMe devices

## Notes

- Script is generic; no host-specific assumptions.
- Some checks need `sudo`; script uses them when available.
- Missing tools are reported as "skipped", not fatal.
