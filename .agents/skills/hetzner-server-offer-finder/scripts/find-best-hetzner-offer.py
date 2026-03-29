#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import re
import sys
import urllib.request
from typing import Any, Dict, List, Optional, Tuple

DEFAULT_URL = "https://www.hetzner.com/_resources/app/data/app/live_data_sb_EUR.json"


def fetch_servers(url: str) -> List[Dict[str, Any]]:
    with urllib.request.urlopen(url, timeout=30) as resp:
        data = json.load(resp)
    if not isinstance(data, dict) or "server" not in data or not isinstance(data["server"], list):
        raise ValueError("Unexpected JSON structure: expected dict with 'server' list")
    return data["server"]


def normalize_text_list(values: Any) -> str:
    if isinstance(values, list):
        return " ".join(str(v) for v in values)
    if values is None:
        return ""
    return str(values)


def text_blob(server: Dict[str, Any]) -> str:
    return " ".join(
        [
            str(server.get("cpu") or ""),
            normalize_text_list(server.get("description")),
            normalize_text_list(server.get("information")),
            normalize_text_list(server.get("ram")),
            normalize_text_list(server.get("hdd_arr")),
            normalize_text_list(server.get("specials")),
            normalize_text_list(server.get("dist")),
            str(server.get("datacenter") or ""),
            str(server.get("traffic") or ""),
        ]
    )


def cpu_release_year(cpu: str) -> Optional[int]:
    c = (cpu or "").strip()

    m = re.search(r"Ryzen\s+\d\s+(\d{4,5})", c, re.IGNORECASE)
    if m:
        series = int(m.group(1))
        lead = int(str(series)[0])
        return {1: 2017, 2: 2018, 3: 2019, 4: 2020, 5: 2020, 6: 2022, 7: 2022, 8: 2024, 9: 2024}.get(lead)

    m = re.search(r"Core\s+i[3579]-?(\d{4,5})", c, re.IGNORECASE)
    if m:
        model = m.group(1)
        gen = int(model[:2]) if len(model) == 5 else int(model[0])
        return {
            2: 2011,
            3: 2012,
            4: 2013,
            5: 2014,
            6: 2015,
            7: 2016,
            8: 2017,
            9: 2018,
            10: 2019,
            11: 2020,
            12: 2021,
            13: 2022,
            14: 2023,
        }.get(gen)

    m = re.search(r"Xeon\s+E-?(\d{4})", c, re.IGNORECASE)
    if m:
        fam = int(m.group(1)[:2])
        return {21: 2018, 22: 2019, 23: 2021, 24: 2023}.get(fam)

    m = re.search(r"EPYC\s+(\d{4})", c, re.IGNORECASE)
    if m:
        gen = int(m.group(1)[-1])
        return {1: 2018, 2: 2019, 3: 2021, 4: 2022, 5: 2024}.get(gen)

    return None


def has_ddr5(server: Dict[str, Any]) -> bool:
    return bool(re.search(r"DDR5", text_blob(server), re.IGNORECASE))


def has_inic(server: Dict[str, Any]) -> bool:
    return bool(re.search(r"\binic\b", text_blob(server), re.IGNORECASE))


def has_ipv4(server: Dict[str, Any]) -> bool:
    return bool(re.search(r"\bIPv4\b", text_blob(server), re.IGNORECASE))


def has_ipv6(server: Dict[str, Any]) -> bool:
    return bool(re.search(r"\bIPv6\b", text_blob(server), re.IGNORECASE))


def disk_counts(server: Dict[str, Any]) -> Tuple[int, int, int]:
    d = server.get("serverDiskData") or {}
    if not isinstance(d, dict):
        return (0, 0, 0)
    nvme = d.get("nvme") if isinstance(d.get("nvme"), list) else []
    sata = d.get("sata") if isinstance(d.get("sata"), list) else []
    hdd = d.get("hdd") if isinstance(d.get("hdd"), list) else []
    return (len(nvme), len(sata), len(hdd))


def has_datacenter_nvme(server: Dict[str, Any]) -> bool:
    t = text_blob(server)
    return bool(re.search(r"NVME", t, re.IGNORECASE) and re.search(r"DATACENTER", t, re.IGNORECASE))


def location_match(server: Dict[str, Any], location_prefix: str) -> bool:
    dc = str(server.get("datacenter") or "")
    return dc.upper().startswith(location_prefix.upper())


def cpu_family_match(cpu: str, family: str) -> bool:
    c = (cpu or "").lower()
    if family == "any":
        return True
    if family == "intel":
        return any(x in c for x in ["intel", "core", "xeon"])
    if family == "amd":
        return any(x in c for x in ["amd", "ryzen", "epyc"])
    if family == "xeon":
        return "xeon" in c
    if family == "epyc":
        return "epyc" in c
    if family == "core":
        return "core i" in c
    if family == "ryzen":
        return "ryzen" in c
    return False


def tri_filter(value: bool, required: Optional[bool]) -> bool:
    if required is None:
        return True
    return value is required


def regex_ok(text: str, include: Optional[str], exclude: Optional[str]) -> bool:
    if include and not re.search(include, text, re.IGNORECASE):
        return False
    if exclude and re.search(exclude, text, re.IGNORECASE):
        return False
    return True


def score_server(
    server: Dict[str, Any],
    cpu_year: Optional[int],
    min_cpu_year: int,
    prefer_ddr5: bool,
    prefer_datacenter_nvme: bool,
    prefer_inic: bool,
) -> float:
    score = 0.0

    if prefer_ddr5 and has_ddr5(server):
        score += 30
    if prefer_datacenter_nvme and has_datacenter_nvme(server):
        score += 25
    if prefer_inic and has_inic(server):
        score += 15

    if cpu_year is not None:
        score += max(0, min(20, (cpu_year - min_cpu_year + 1) * 4))

    price = float(server.get("price") or 0)
    score -= price / 20.0
    return score


def parse_args() -> argparse.Namespace:
    current_year = dt.datetime.now(dt.UTC).year
    p = argparse.ArgumentParser(
        description="Find and rank Hetzner Server Auction offers from the live JSON feed."
    )

    p.add_argument("regions", nargs="*", help="Datacenter prefixes (e.g. FSN HEL NBG). Default: FSN")
    p.add_argument("--json-url", default=DEFAULT_URL, help="Source JSON URL")

    # Core hardware filters
    p.add_argument("--ram-min", type=int, default=64, help="Minimum RAM in GB (default: 64)")
    p.add_argument("--ram-max", type=int, default=128, help="Maximum RAM in GB (default: 128)")
    p.add_argument("--ram-exact", type=int, help="Exact RAM in GB")

    p.add_argument("--cpu-family", choices=["any", "intel", "amd", "xeon", "epyc", "core", "ryzen"], default="any", help="CPU family filter")
    p.add_argument("--cpu-regex", help="Include CPU model regex")
    p.add_argument("--exclude-cpu-regex", help="Exclude CPU model regex")
    p.add_argument("--min-cpu-year", type=int, default=current_year - 5, help=f"Minimum CPU release year (default: {current_year - 5})")
    p.add_argument("--max-cpu-year", type=int, help="Maximum CPU release year")
    p.add_argument("--allow-unknown-cpu-year", action="store_true", help="Allow CPUs where release year cannot be inferred")

    # Cost filters
    p.add_argument("--price-min", type=float, help="Minimum monthly price")
    p.add_argument("--price-max", type=float, help="Maximum monthly price")
    p.add_argument("--hourly-price-min", type=float, help="Minimum hourly price")
    p.add_argument("--hourly-price-max", type=float, help="Maximum hourly price")
    p.add_argument("--setup-price-min", type=float, help="Minimum setup price")
    p.add_argument("--setup-price-max", type=float, help="Maximum setup price")
    p.add_argument("--require-zero-setup-cost", action="store_true", default=True, help="Require setup_price == 0 (default: true)")
    p.add_argument("--no-require-zero-setup-cost", dest="require_zero_setup_cost", action="store_false", help="Allow setup_price > 0")

    # Boolean hard filters
    p.add_argument("--require-ecc", action="store_true", default=True, help="Require ECC RAM (default: true)")
    p.add_argument("--no-require-ecc", dest="require_ecc", action="store_false", help="Do not require ECC")

    p.add_argument("--require-nvme", action="store_true", default=True, help="Require NVMe disks (default: true)")
    p.add_argument("--no-require-nvme", dest="require_nvme", action="store_false", help="Do not require NVMe")

    p.add_argument("--require-ddr5", action="store_true", help="Hard-require DDR5")
    p.add_argument("--forbid-ddr5", action="store_true", help="Exclude DDR5 servers")

    p.add_argument("--require-datacenter-nvme", action="store_true", help="Hard-require Datacenter NVMe")
    p.add_argument("--forbid-datacenter-nvme", action="store_true", help="Exclude Datacenter NVMe")

    p.add_argument("--require-inic", action="store_true", help="Hard-require iNIC")
    p.add_argument("--forbid-inic", action="store_true", help="Exclude iNIC")

    p.add_argument("--require-ipv4", action="store_true", help="Hard-require IPv4")
    p.add_argument("--require-ipv6", action="store_true", help="Hard-require IPv6")
    p.add_argument("--require-fixed-price", action="store_true", help="Require fixed_price=true")

    # Disk shape filters
    p.add_argument("--nvme-min", type=int, help="Minimum NVMe disk count")
    p.add_argument("--nvme-max", type=int, help="Maximum NVMe disk count")
    p.add_argument("--sata-min", type=int, help="Minimum SATA SSD count")
    p.add_argument("--sata-max", type=int, help="Maximum SATA SSD count")
    p.add_argument("--hdd-min", type=int, help="Minimum HDD count")
    p.add_argument("--hdd-max", type=int, help="Maximum HDD count")
    p.add_argument("--disk-count-min", type=int, help="Minimum total drive count")
    p.add_argument("--disk-count-max", type=int, help="Maximum total drive count")
    p.add_argument("--disk-size-min", type=int, help="Minimum disk size field in GB (hdd_size)")
    p.add_argument("--disk-size-max", type=int, help="Maximum disk size field in GB (hdd_size)")

    # Misc filters
    p.add_argument("--bandwidth-min", type=float, help="Minimum bandwidth (Mbit/s)")
    p.add_argument("--traffic-regex", help="Regex match for traffic field")
    p.add_argument("--datacenter-regex", help="Regex include for datacenter, e.g. 'FSN1-DC7'")
    p.add_argument("--exclude-datacenter-regex", help="Regex exclude for datacenter")
    p.add_argument("--include-text", help="Regex include over combined text fields")
    p.add_argument("--exclude-text", help="Regex exclude over combined text fields")

    # Preferences used in ranking (soft, not hard constraints)
    p.add_argument("--prefer-ddr5", action="store_true", default=True, help="Prefer DDR5 in score (default: true)")
    p.add_argument("--no-prefer-ddr5", dest="prefer_ddr5", action="store_false", help="Disable DDR5 preference")
    p.add_argument("--prefer-datacenter-nvme", action="store_true", default=True, help="Prefer Datacenter NVMe in score (default: true)")
    p.add_argument("--no-prefer-datacenter-nvme", dest="prefer_datacenter_nvme", action="store_false", help="Disable Datacenter NVMe preference")
    p.add_argument("--prefer-inic", action="store_true", default=True, help="Prefer iNIC in score (default: true)")
    p.add_argument("--no-prefer-inic", dest="prefer_inic", action="store_false", help="Disable iNIC preference")

    p.add_argument("--sort-by", choices=["score", "price", "hourly", "ram"], default="score", help="Result sort key")
    p.add_argument("--max-results", type=int, default=10, help="Max rows to print (default: 10)")

    return p.parse_args()


def in_range(value: float, minv: Optional[float], maxv: Optional[float]) -> bool:
    if minv is not None and value < minv:
        return False
    if maxv is not None and value > maxv:
        return False
    return True


def main() -> int:
    args = parse_args()
    regions = [r.upper() for r in (args.regions or ["FSN"])]

    if args.require_ddr5 and args.forbid_ddr5:
        print("ERROR: cannot use both --require-ddr5 and --forbid-ddr5", file=sys.stderr)
        return 1
    if args.require_datacenter_nvme and args.forbid_datacenter_nvme:
        print("ERROR: cannot use both --require-datacenter-nvme and --forbid-datacenter-nvme", file=sys.stderr)
        return 1
    if args.require_inic and args.forbid_inic:
        print("ERROR: cannot use both --require-inic and --forbid-inic", file=sys.stderr)
        return 1

    try:
        servers = fetch_servers(args.json_url)
    except Exception as e:
        print(f"ERROR: failed to fetch/parse JSON: {e}", file=sys.stderr)
        return 1

    filtered: List[Tuple[float, Dict[str, Any], Dict[str, Any]]] = []

    for s in servers:
        if not any(location_match(s, reg) for reg in regions):
            continue

        dc = str(s.get("datacenter") or "")
        if not regex_ok(dc, args.datacenter_regex, args.exclude_datacenter_regex):
            continue

        blob = text_blob(s)
        if not regex_ok(blob, args.include_text, args.exclude_text):
            continue

        ram_size = int(s.get("ram_size") or 0)
        if args.ram_exact is not None and ram_size != args.ram_exact:
            continue
        if ram_size < args.ram_min or ram_size > args.ram_max:
            continue

        if args.require_ecc and not bool(s.get("is_ecc")):
            continue

        nvme, sata, hdd = disk_counts(s)
        total_disks = int(s.get("hdd_count") or (nvme + sata + hdd))
        if args.require_nvme and nvme <= 0:
            continue

        if not in_range(float(nvme), args.nvme_min, args.nvme_max):
            continue
        if not in_range(float(sata), args.sata_min, args.sata_max):
            continue
        if not in_range(float(hdd), args.hdd_min, args.hdd_max):
            continue
        if not in_range(float(total_disks), args.disk_count_min, args.disk_count_max):
            continue

        disk_size = float(s.get("hdd_size") or 0)
        if not in_range(disk_size, args.disk_size_min, args.disk_size_max):
            continue

        price = float(s.get("price") or 0)
        hourly = float(s.get("hourly_price") or 0)
        setup_price = float(s.get("setup_price") or 0)

        if not in_range(price, args.price_min, args.price_max):
            continue
        if not in_range(hourly, args.hourly_price_min, args.hourly_price_max):
            continue
        if not in_range(setup_price, args.setup_price_min, args.setup_price_max):
            continue

        if args.require_zero_setup_cost and setup_price != 0:
            continue

        if args.bandwidth_min is not None and float(s.get("bandwidth") or 0) < args.bandwidth_min:
            continue
        if args.traffic_regex and not re.search(args.traffic_regex, str(s.get("traffic") or ""), re.IGNORECASE):
            continue

        if args.require_fixed_price and not bool(s.get("fixed_price")):
            continue

        ddr5 = has_ddr5(s)
        inic = has_inic(s)
        datacenter_nvme = has_datacenter_nvme(s)
        ipv4 = has_ipv4(s)
        ipv6 = has_ipv6(s)

        if args.require_ddr5 and not ddr5:
            continue
        if args.forbid_ddr5 and ddr5:
            continue

        if args.require_datacenter_nvme and not datacenter_nvme:
            continue
        if args.forbid_datacenter_nvme and datacenter_nvme:
            continue

        if args.require_inic and not inic:
            continue
        if args.forbid_inic and inic:
            continue

        if args.require_ipv4 and not ipv4:
            continue
        if args.require_ipv6 and not ipv6:
            continue

        cpu = str(s.get("cpu") or "")
        if not cpu_family_match(cpu, args.cpu_family):
            continue
        if args.cpu_regex and not re.search(args.cpu_regex, cpu, re.IGNORECASE):
            continue
        if args.exclude_cpu_regex and re.search(args.exclude_cpu_regex, cpu, re.IGNORECASE):
            continue

        year = cpu_release_year(cpu)
        if year is None and not args.allow_unknown_cpu_year:
            continue
        if year is not None:
            if args.min_cpu_year is not None and year < args.min_cpu_year:
                continue
            if args.max_cpu_year is not None and year > args.max_cpu_year:
                continue

        meta = {
            "cpu_year": year,
            "ddr5": ddr5,
            "inic": inic,
            "datacenter_nvme": datacenter_nvme,
            "nvme_count": nvme,
            "sata_count": sata,
            "hdd_count": hdd,
            "setup_price": setup_price,
            "ipv4": ipv4,
            "ipv6": ipv6,
            "hourly": hourly,
            "price": price,
        }

        score = score_server(
            s,
            year,
            args.min_cpu_year or (dt.datetime.now(dt.UTC).year - 5),
            args.prefer_ddr5,
            args.prefer_datacenter_nvme,
            args.prefer_inic,
        )
        filtered.append((score, s, meta))

    if args.sort_by == "score":
        filtered.sort(key=lambda x: (-x[0], x[2]["price"], -int(x[1].get("ram_size") or 0)))
    elif args.sort_by == "price":
        filtered.sort(key=lambda x: (x[2]["price"], -x[0]))
    elif args.sort_by == "hourly":
        filtered.sort(key=lambda x: (x[2]["hourly"], -x[0]))
    elif args.sort_by == "ram":
        filtered.sort(key=lambda x: (-int(x[1].get("ram_size") or 0), x[2]["price"], -x[0]))

    print("Hetzner best-offer finder")
    print("-" * 100)
    print(f"Source: {args.json_url}")
    print(f"Regions: {', '.join(regions)}")
    print(
        "Constraints: "
        f"ECC={'yes' if args.require_ecc else 'no'}, RAM={args.ram_min}-{args.ram_max}GB"
        + (f", RAM exact={args.ram_exact}GB" if args.ram_exact is not None else "")
        + f", NVMe_required={'yes' if args.require_nvme else 'no'}, setup_cost_zero={'yes' if args.require_zero_setup_cost else 'no'}"
        + f", cpu_family={args.cpu_family}, min_cpu_year={args.min_cpu_year}"
        + (f", max_cpu_year={args.max_cpu_year}" if args.max_cpu_year is not None else "")
    )
    print(
        "Soft preferences: "
        f"DDR5={'yes' if args.prefer_ddr5 else 'no'}, Datacenter_NVMe={'yes' if args.prefer_datacenter_nvme else 'no'}, iNIC={'yes' if args.prefer_inic else 'no'}"
    )
    print()

    if not filtered:
        print("No offers matched all hard constraints.")
        print("Tips: relax --min-cpu-year, add --allow-unknown-cpu-year, or loosen hard requires.")
        print("Note: setup time is not explicitly present in this JSON feed.")
        return 2

    print(f"Top {min(args.max_results, len(filtered))} matches (sorted by {args.sort_by}):")
    print("rank  price€  setup€  dc         cpu                       year  ram  ecc  nvme  ddr5  dcnvme  inic  id")

    for i, (score, s, m) in enumerate(filtered[: args.max_results], start=1):
        price = m["price"]
        setup = m["setup_price"]
        dc = str(s.get("datacenter") or "")
        cpu = str(s.get("cpu") or "")
        cpu_short = (cpu[:24] + "…") if len(cpu) > 25 else cpu.ljust(25)
        year = str(m["cpu_year"] or "?").rjust(4)
        ram = f"{int(s.get('ram_size') or 0):>3}G"
        print(
            f"{i:>4}  {price:>6.2f}  {setup:>6.2f}  {dc:<9}  {cpu_short:<25}  {year}  "
            f"{ram:>4}  {'Y' if s.get('is_ecc') else 'N':>3}  {m['nvme_count']:>4}  "
            f"{'Y' if m['ddr5'] else 'N':>4}  {'Y' if m['datacenter_nvme'] else 'N':>6}  {'Y' if m['inic'] else 'N':>4}  {s.get('id')}"
        )

    best_score, best, best_m = filtered[0]
    print()
    print("Best match:")
    print(f"- ID: {best.get('id')}")
    print(f"- Price: €{best_m['price']:.2f} / month")
    print(f"- Hourly: €{best_m['hourly']:.4f}")
    print(f"- Setup cost: €{best_m['setup_price']:.2f}")
    print(f"- Datacenter: {best.get('datacenter')}")
    print(f"- CPU: {best.get('cpu')} (year: {best_m['cpu_year'] if best_m['cpu_year'] else 'unknown'})")
    print(f"- RAM: {best.get('ram_size')} GB ({'ECC' if best.get('is_ecc') else 'non-ECC'})")
    print(f"- Disks: NVMe={best_m['nvme_count']}, SATA={best_m['sata_count']}, HDD={best_m['hdd_count']}")
    print(f"- DDR5: {'yes' if best_m['ddr5'] else 'no'}")
    print(f"- Datacenter NVMe: {'yes' if best_m['datacenter_nvme'] else 'no'}")
    print(f"- iNIC: {'yes' if best_m['inic'] else 'no'}")
    print(f"- IPv4: {'yes' if best_m['ipv4'] else 'no'} | IPv6: {'yes' if best_m['ipv6'] else 'no'}")
    print(f"- Score: {best_score:.2f}")
    print()
    print("Note: setup time is not explicitly present in this JSON feed; setup cost is.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
