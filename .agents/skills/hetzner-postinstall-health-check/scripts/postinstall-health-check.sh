#!/usr/bin/env bash
set -euo pipefail

IFACE=""
JOURNAL_LINES=120
DO_SMART=1
DO_EFI=1
DO_NFT=1

usage() {
  cat <<'EOF'
Usage: postinstall-health-check.sh [options]

Options:
  --iface <name>         Interface to check (default: auto via default route)
  --journal-lines <n>    Number of boot error log lines (default: 120)
  --no-smart             Skip SMART checks
  --no-efi               Skip efibootmgr check
  --no-nft               Skip nftables check
  -h, --help             Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iface)
      IFACE="${2:-}"; shift 2 ;;
    --journal-lines)
      JOURNAL_LINES="${2:-}"; shift 2 ;;
    --no-smart)
      DO_SMART=0; shift ;;
    --no-efi)
      DO_EFI=0; shift ;;
    --no-nft)
      DO_NFT=0; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ -z "$IFACE" ]]; then
  IFACE="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
fi

have() { command -v "$1" >/dev/null 2>&1; }
run() { echo "\n=== $* ==="; "$@"; }
run_maybe() {
  local title="$1"; shift
  echo "\n=== ${title} ==="
  if "$@"; then
    :
  else
    echo "(check failed)"
  fi
}

echo "Hetzner post-install health check"
echo "Interface: ${IFACE:-unknown}"

run_maybe "nixos-rebuild dry-run" sudo nixos-rebuild dry-run
run "systemctl --failed" systemctl --failed || true
run_maybe "boot errors (journalctl -p err -b)" bash -lc "sudo journalctl -p err -b --no-pager | tail -n ${JOURNAL_LINES}"

run "cat /proc/mdstat" cat /proc/mdstat
if have mdadm; then
  for md in /dev/md/*; do
    [[ -e "$md" ]] || continue
    run "mdadm --detail $md" sudo mdadm --detail "$md"
  done
else
  echo "\n=== mdadm ===\nmdadm not installed; skipped"
fi

run "lsblk -f" lsblk -f

echo "\n=== boot mounts ==="
findmnt /boot || true
findmnt /boot2 || true

if [[ "$DO_EFI" -eq 1 ]]; then
  if have efibootmgr; then
    run_maybe "efibootmgr -v" sudo efibootmgr -v
  else
    echo "\n=== efibootmgr ===\nefibootmgr not installed; skipped"
  fi
fi

run "ip -br addr" ip -br addr
run "ip route" ip route
run "ip -6 route" ip -6 route

if [[ -n "$IFACE" ]]; then
  run_maybe "ip -6 addr show dev $IFACE" ip -6 addr show dev "$IFACE"
fi

if have ping; then
  run_maybe "ping -c 2 1.1.1.1" ping -c 2 1.1.1.1
else
  echo "\n=== ping ===\nping not installed; skipped"
fi

if have ping6; then
  run_maybe "ping6 -c 2 2606:4700:4700::1111" ping6 -c 2 2606:4700:4700::1111
elif have ping; then
  run_maybe "ping -6 -c 2 2606:4700:4700::1111" ping -6 -c 2 2606:4700:4700::1111
else
  echo "\n=== ipv6 ping ===\nping/ping6 not installed; skipped"
fi

run "ss -lntp | grep :22" bash -lc 'ss -lntp | grep :22 || true'
run "timedatectl status" timedatectl status

if have resolvectl; then
  run_maybe "resolvectl status" resolvectl status
else
  echo "\n=== resolvectl ===\nresolvectl not available; skipped"
fi

run_maybe "getent hosts nixos.org" getent hosts nixos.org

if [[ "$DO_NFT" -eq 1 ]]; then
  if have nft; then
    run_maybe "nft list ruleset" sudo nft list ruleset
  else
    echo "\n=== nftables ===\nnft not installed; skipped"
  fi
fi

if [[ "$DO_SMART" -eq 1 ]]; then
  if have smartctl; then
    mapfile -t nvmes < <(ls /dev/nvme*n1 2>/dev/null || true)
    if [[ ${#nvmes[@]} -eq 0 ]]; then
      echo "\n=== smartctl ===\nNo NVMe namespaces found; skipped"
    else
      for d in "${nvmes[@]}"; do
        run_maybe "smartctl -H $d" sudo smartctl -H "$d"
      done
    fi
  else
    echo "\n=== smartctl ===\nsmartctl not installed; skipped"
  fi
fi

echo "\nHealth check complete."
