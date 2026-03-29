---
name: hetzner-server-offer-finder
description: Finds the best Hetzner Server Auction offers from live_data_sb_EUR.json using constraints (ECC, RAM range, NVMe, setup cost, CPU year) and preferences (DDR5, Datacenter NVMe, iNIC). Use when selecting a dedicated server offer quickly.
---

# Hetzner Server Offer Finder

## Purpose
Find the **best matching Server Auction offer** for your requirements.

This skill supports two modes:
1. **Simple mode** (recommended): opinionated command for modern FSN servers.
2. **Advanced mode**: full filter surface for custom searches.

## Data source
- Search UI: `https://www.hetzner.com/sb/#ecc=true&ram_from=64&ram_to=128&driveType=nvme&location=FSN&additional=iNIC`
- Live feed: `https://www.hetzner.com/_resources/app/data/app/live_data_sb_EUR.json`

## Scripts
From this skill directory:

```bash
# Simple profile (easy mode)
./scripts/find-best-hetzner-offer-simple.sh

# Advanced profile (all options)
./scripts/find-best-hetzner-offer.py
```

---

## How we found the final server (project decision log)

Target criteria:
- FSN
- ECC
- DDR5
- iNIC
- NVMe SSD
- CPU year >= 2021
- setup cost = 0
- prefer Datacenter NVMe

Command used:

```bash
./scripts/find-best-hetzner-offer.py FSN \
  --require-ecc --require-ddr5 --require-inic \
  --require-nvme --nvme-min 2 --require-datacenter-nvme \
  --min-cpu-year 2021 --require-zero-setup-cost \
  --disk-size-min 1800 --price-max 100 --max-results 5
```

Result shortlist had two near-identical top offers:
- `2878158` (FSN1-DC7, NIC Intel i210-AT)
- `2878171` (FSN1-DC3, NIC Intel i225-LM)

Chosen in this project: **2878158** (small preference for i210 maturity).

---

## Simple mode (recommended)

Use this first for day-to-day searching:

```bash
./scripts/find-best-hetzner-offer-simple.sh
```

This wrapper applies a practical modern profile automatically.
You can still append extra options, e.g. tighter budget:

```bash
./scripts/find-best-hetzner-offer-simple.sh --price-max 95
```

---

## Advanced mode examples

Default FSN run:
```bash
./scripts/find-best-hetzner-offer.py
```

Compare regions:
```bash
./scripts/find-best-hetzner-offer.py FSN HEL
```

Xeon only:
```bash
./scripts/find-best-hetzner-offer.py --cpu-family xeon --min-cpu-year 2018
```

EPYC only:
```bash
./scripts/find-best-hetzner-offer.py --cpu-family epyc --allow-unknown-cpu-year
```

Strict modern ECC NVMe profile:
```bash
./scripts/find-best-hetzner-offer.py FSN \
  --require-ecc --require-ddr5 --require-inic \
  --require-nvme --nvme-min 2 --require-datacenter-nvme \
  --min-cpu-year 2021 --require-zero-setup-cost
```

---

## Key options (advanced script)
- Regions/datacenter:
  - `regions` positional: `FSN HEL NBG ...`
  - `--datacenter-regex`, `--exclude-datacenter-regex`
- CPU:
  - `--cpu-family {any,intel,amd,xeon,epyc,core,ryzen}`
  - `--cpu-regex`, `--exclude-cpu-regex`
  - `--min-cpu-year`, `--max-cpu-year`, `--allow-unknown-cpu-year`
- RAM:
  - `--ram-min`, `--ram-max`, `--ram-exact`
- Price/setup:
  - `--price-min`, `--price-max`
  - `--hourly-price-min`, `--hourly-price-max`
  - `--setup-price-min`, `--setup-price-max`
  - `--require-zero-setup-cost` / `--no-require-zero-setup-cost`
- Disk filters:
  - `--require-nvme` / `--no-require-nvme`
  - `--nvme-min`, `--nvme-max`
  - `--sata-min`, `--sata-max`
  - `--hdd-min`, `--hdd-max`
  - `--disk-count-min`, `--disk-count-max`
  - `--disk-size-min`, `--disk-size-max`
- Feature hard-filters:
  - `--require-ecc` / `--no-require-ecc`
  - `--require-ddr5` / `--forbid-ddr5`
  - `--require-datacenter-nvme` / `--forbid-datacenter-nvme`
  - `--require-inic` / `--forbid-inic`
  - `--require-ipv4`, `--require-ipv6`, `--require-fixed-price`
- Text/traffic:
  - `--include-text`, `--exclude-text`, `--traffic-regex`, `--bandwidth-min`
- Ranking/output:
  - `--sort-by {score,price,hourly,ram}`
  - `--max-results`

## Output
- Ranked table of matching offers
- Best-match summary with key specs
- Notes about unavailable fields

## Recommended workflow (fast + repeatable)
1. Run simple profile:
   ```bash
   ./scripts/find-best-hetzner-offer-simple.sh
   ```
2. If there are multiple top ties, pick by:
   - lower monthly price first
   - Datacenter NVMe = yes
   - NIC preference (for this project: slight preference for Intel i210)
3. Re-run with budget guardrail:
   ```bash
   ./scripts/find-best-hetzner-offer-simple.sh --price-max 100
   ```
4. If no matches, relax exactly one constraint at a time.

## Notes
- Feed includes **setup cost** (`setup_price`) but does **not clearly expose setup time**.
- CPU release year is heuristic from model naming.
- If constraints are too strict, relax one of:
  - `--min-cpu-year`
  - `--require-datacenter-nvme`
  - budget caps (`--price-max`)
