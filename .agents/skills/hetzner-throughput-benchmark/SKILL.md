---
name: hetzner-throughput-benchmark
description: Compares Hetzner region download throughput (min/avg/p95) using 100MB, 1GB, or 10GB test files. Use when selecting a region for bulk transfers like image pulls, backups, and artifact downloads.
---

# Hetzner Throughput Benchmark

## Purpose
Compare **download throughput** between Hetzner regions.

Use this when you care about sustained transfer rates (artifact pulls, backups, large image downloads).

## Script
From this skill directory, run:

```bash
./scripts/hetzner-speed-compare.sh hel1 fsn1
```

## Regions
`nbg1 fsn1 hel1 ash hil sin`

## Useful commands

Run 3 samples with a bigger file:
```bash
./scripts/hetzner-speed-compare.sh -f 1GB -n 3 -t 120 hel1 fsn1
```

Run across all regions:
```bash
./scripts/hetzner-speed-compare.sh --all
```

## Options
- `-f, --file <SIZE>`: `100MB | 1GB | 10GB`
- `-n, --samples <N>`: samples per region
- `-t, --timeout <SEC>`: timeout per sample
- `--all`: all supported regions

## Output
Per region:
- per-sample throughput in MiB/s and Mbps
- summary `min/avg/p95`

## Notes
- This script intentionally excludes latency checks.
- For latency and route quality, use `../hetzner-latency-benchmark/SKILL.md`.
