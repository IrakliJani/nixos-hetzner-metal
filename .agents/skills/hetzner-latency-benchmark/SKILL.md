---
name: hetzner-latency-benchmark
description: Compares Hetzner region latency quality with ICMP RTT and optional TCP connect, TLS, and TTFB timing (min/avg/p95), plus optional traceroute hops. Use when picking the best region for SSH responsiveness and request latency.
---

# Hetzner Latency Benchmark

## Purpose
Compare **latency quality** between Hetzner regions.

Use this when SSH responsiveness, API snappiness, or request/response time matters more than bulk transfer speed.

## Script
From this skill directory, run:

```bash
./scripts/hetzner-latency-compare.sh hel1 fsn1
```

## Regions
`nbg1 fsn1 hel1 ash hil sin`

## Useful commands

Higher confidence ICMP test + TCP timing samples:
```bash
./scripts/hetzner-latency-compare.sh -c 50 --tcp-samples 10 hel1 fsn1
```

Include traceroute hops:
```bash
./scripts/hetzner-latency-compare.sh -c 30 --tcp-samples 5 --hops --max-hops 20 hel1 fsn1
```

Test every region:
```bash
./scripts/hetzner-latency-compare.sh --all
```

## Options
- `-c, --count <N>`: ICMP ping count
- `--tcp-samples <N>`: HTTPS timing samples (`time_connect`, `time_appconnect`, `time_starttransfer`)
- `--curl-timeout <SEC>`: timeout per TCP sample
- `--hops`: include traceroute output
- `--max-hops <N>`: traceroute lines to print
- `--all`: all supported regions

## Output
Per region:
- ICMP RTT `min/avg/p95`
- packet loss
- TCP connect / TLS done / TTFB `min/avg/p95`
- optional traceroute hops

## Notes
- `p95` is a useful "bad-but-common" latency indicator.
- Run multiple times (different times of day) for better decisions.
- For throughput-focused testing, use `../hetzner-throughput-benchmark/SKILL.md`.
