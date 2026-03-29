#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./install-with-nixos-anywhere.sh <target-host> <flake-attr>
# Example:
#   ./install-with-nixos-anywhere.sh root@hetzner-fsn1-ij1 hetzner-fsn1-ij1

TARGET_HOST="${1:-}"
FLAKE_ATTR="${2:-}"

if [[ -z "$TARGET_HOST" || -z "$FLAKE_ATTR" ]]; then
  echo "Usage: $0 <target-host> <flake-attr>" >&2
  exit 1
fi

# Requires local nix with flakes and nixos-anywhere.
exec nix run github:nix-community/nixos-anywhere -- \
  --build-on remote \
  --flake ".#${FLAKE_ATTR}" \
  "$TARGET_HOST"
