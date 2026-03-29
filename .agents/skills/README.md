# Skills

This folder contains reusable operator skills for choosing Hetzner locations and server offers.

## Available skills

- `.agents/skills/hetzner-throughput-benchmark/SKILL.md`
  - Uses `.agents/skills/hetzner-throughput-benchmark/scripts/hetzner-speed-compare.sh`
  - Measures download throughput only (no latency metrics)

- `.agents/skills/hetzner-latency-benchmark/SKILL.md`
  - Uses `.agents/skills/hetzner-latency-benchmark/scripts/hetzner-latency-compare.sh`
  - Measures latency quality (ICMP + optional TCP/TLS/TTFB + optional hops)

- `.agents/skills/hetzner-server-offer-finder/SKILL.md`
  - Uses `.agents/skills/hetzner-server-offer-finder/scripts/find-best-hetzner-offer-simple.sh` (recommended) and `.agents/skills/hetzner-server-offer-finder/scripts/find-best-hetzner-offer.py` (advanced)
  - Ranks Server Auction offers from Hetzner live JSON by constraints and preferences (ECC, RAM, NVMe, setup cost, CPU year, DDR5, Datacenter NVMe, iNIC)

- `.agents/skills/hetzner-nixos-install/SKILL.md`
  - Uses `.agents/skills/hetzner-nixos-install/scripts/rescue-preflight.sh` and `.agents/skills/hetzner-nixos-install/scripts/install-with-nixos-anywhere.sh`
  - Evolving runbook for rescue -> declarative NixOS install with UEFI + disko + RAID1

- `.agents/skills/hetzner-postinstall-health-check/SKILL.md`
  - Uses `.agents/skills/hetzner-postinstall-health-check/scripts/postinstall-health-check.sh`
  - Runs a generic post-install audit (services, RAID, mounts, network, SSH, time, DNS, firewall, optional EFI/SMART)

Benchmark scripts support selecting specific regions or all regions.
