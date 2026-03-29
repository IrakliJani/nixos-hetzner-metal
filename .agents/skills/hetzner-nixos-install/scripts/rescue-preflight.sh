#!/usr/bin/env bash
set -euo pipefail

echo "=== UEFI mode ==="
[ -d /sys/firmware/efi ] && echo "UEFI" || echo "Legacy/CSM"

echo

echo "=== Host / Time ==="
hostnamectl || true
date -u

echo

echo "=== Network ==="
ip -br addr
ip route
ip -6 route

echo

echo "=== Disks ==="
lsblk -o NAME,SIZE,TYPE,MODEL

echo

echo "=== DNS/Reachability ==="
getent hosts nixos.org || true
ping -c 2 1.1.1.1 || true
ping6 -c 2 2606:4700:4700::1111 || true

echo

echo "=== End preflight ==="
