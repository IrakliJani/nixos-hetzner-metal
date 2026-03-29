# nixos-hetzner-metal

Reusable workflow for selecting a Hetzner server, benchmarking location quality, installing NixOS declaratively, and running post-install health checks.

## What is in this repo

- Flake-based NixOS host config
- Disk layout via `disko` (UEFI + RAID1 example)
- Nix config file for host/user settings (`config.nix`)
- Skills under `.agents/skills/` for:
  - location latency benchmark
  - throughput benchmark
  - server offer filtering/ranking
  - NixOS install runbook
  - post-install health checks

## Quick start (agent-first)

Use [Pi](https://pi.dev/) or your favorite coding agent.

1. Clone this repo and open it in your agent context.
2. Edit `config.nix` and set host/users/network values.
3. Tell the agent to load skills from `.agents/skills/` and run the flow in order:
   - **1** `hetzner-latency-benchmark` + `hetzner-throughput-benchmark`
   - **2** `hetzner-server-offer-finder`
   - **3** `hetzner-nixos-install`
   - **4** `hetzner-postinstall-health-check`
4. Review/approve each risky step (ordering, rescue mode actions, install, reboot checks).

### Suggested agent prompt

```text
Load skills from .agents/skills and execute this workflow in order:
1) hetzner-latency-benchmark + hetzner-throughput-benchmark
2) hetzner-server-offer-finder
3) hetzner-nixos-install
4) hetzner-postinstall-health-check

Pause before destructive actions and ask for approval.
Use values from `config.nix` for host-specific settings.
```

## Related posts

- [Installing NixOS on Hetzner metal](https://iraklijani.com/blog/installing-nixos-on-hetzner-metal/)

