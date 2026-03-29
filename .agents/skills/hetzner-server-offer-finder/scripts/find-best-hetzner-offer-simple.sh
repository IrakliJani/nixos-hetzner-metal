#!/usr/bin/env bash
set -euo pipefail

# Opinionated wrapper around find-best-hetzner-offer.py
# Keeps day-to-day usage simple while advanced filtering remains available.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="${SCRIPT_DIR}/find-best-hetzner-offer.py"

# Default "modern ECC NVMe" profile (close to the decision used in this project)
# - FSN
# - ECC, DDR5, iNIC
# - NVMe (>=2), Datacenter NVMe
# - zero setup cost
# - CPU year >= 2021
# - RAM 64-128 GB

exec "$PY_SCRIPT" FSN \
  --require-ecc \
  --require-ddr5 \
  --require-inic \
  --require-nvme \
  --nvme-min 2 \
  --require-datacenter-nvme \
  --min-cpu-year 2021 \
  --ram-min 64 --ram-max 128 \
  --require-zero-setup-cost \
  --max-results 10 \
  "$@"
