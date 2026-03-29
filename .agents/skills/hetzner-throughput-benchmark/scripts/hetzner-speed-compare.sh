#!/usr/bin/env bash
set -euo pipefail

# Hetzner throughput tester (download speed only)
# Usage examples:
#   ./hetzner-speed-compare.sh
#   ./hetzner-speed-compare.sh hel1 fsn1
#   ./hetzner-speed-compare.sh -f 1GB -t 90 -n 3 hel1 fsn1
#   ./hetzner-speed-compare.sh --all

FILE="100MB"   # 100MB | 1GB | 10GB
TIMEOUT=30
SAMPLES=1
RUN_ALL=0

usage() {
  cat <<'EOF'
Usage: hetzner-speed-compare.sh [options] [regions...]

Regions:
  nbg1 fsn1 hel1 ash hil sin

Options:
  -f, --file <SIZE>      Test file size: 100MB | 1GB | 10GB (default: 100MB)
  -t, --timeout <SEC>    Curl timeout per sample (default: 30)
  -n, --samples <N>      Download samples per region (default: 1)
      --all              Test all regions
  -h, --help             Show this help

Examples:
  ./hetzner-speed-compare.sh hel1 fsn1
  ./hetzner-speed-compare.sh -f 1GB -t 90 -n 3 hel1 fsn1
  ./hetzner-speed-compare.sh --all
EOF
}

declare -A HOSTS=(
  [nbg1]="nbg1-speed.hetzner.com"
  [fsn1]="fsn1-speed.hetzner.com"
  [hel1]="hel1-speed.hetzner.com"
  [ash]="ash-speed.hetzner.com"
  [hil]="hil-speed.hetzner.com"
  [sin]="sin-speed.hetzner.com"
)

calc_stats() {
  # stdin: one numeric value per line
  sort -n | awk '
    { a[NR] = $1; s += $1 }
    END {
      if (NR == 0) {
        print "N/A N/A N/A 0"
        exit
      }
      p95i = int(0.95 * NR)
      if (p95i < 1) p95i = 1
      if (p95i < 0.95 * NR) p95i++
      printf "%.2f %.2f %.2f %d", a[1], s/NR, a[p95i], NR
    }
  '
}

regions=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--file)
      [[ -n "${2:-}" ]] || { echo "--file requires a value" >&2; exit 1; }
      FILE="$2"; shift 2 ;;
    -t|--timeout)
      [[ -n "${2:-}" ]] || { echo "--timeout requires a value" >&2; exit 1; }
      TIMEOUT="$2"; shift 2 ;;
    -n|--samples)
      [[ -n "${2:-}" ]] || { echo "--samples requires a value" >&2; exit 1; }
      SAMPLES="$2"; shift 2 ;;
    --all)
      RUN_ALL=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      regions+=("$1"); shift ;;
  esac
done

case "$FILE" in
  100MB|1GB|10GB) ;;
  *)
    echo "Invalid --file value: $FILE (allowed: 100MB, 1GB, 10GB)" >&2
    exit 1 ;;
esac

[[ "$TIMEOUT" =~ ^[0-9]+$ ]] || { echo "--timeout must be an integer" >&2; exit 1; }
[[ "$SAMPLES" =~ ^[0-9]+$ ]] || { echo "--samples must be an integer" >&2; exit 1; }
(( TIMEOUT >= 1 )) || { echo "--timeout must be >= 1" >&2; exit 1; }
(( SAMPLES >= 1 )) || { echo "--samples must be >= 1" >&2; exit 1; }

if [[ "$RUN_ALL" -eq 1 ]]; then
  regions=(nbg1 fsn1 hel1 ash hil sin)
elif [[ ${#regions[@]} -eq 0 ]]; then
  regions=(fsn1 hel1)
fi

for r in "${regions[@]}"; do
  if [[ -z "${HOSTS[$r]+x}" ]]; then
    echo "Unknown region: $r" >&2
    echo "Valid regions: nbg1 fsn1 hel1 ash hil sin" >&2
    exit 1
  fi
done

echo "Testing throughput for regions: ${regions[*]}"
echo "File: ${FILE}.bin | Timeout/sample: ${TIMEOUT}s | Samples/region: ${SAMPLES}"
echo

for site in "${regions[@]}"; do
  host="${HOSTS[$site]}"
  file_url="https://${host}/${FILE}.bin"
  rates_mbps=""
  success_count=0

  echo "=============================="
  echo "Region: $site ($host)"
  echo "=============================="
  echo "Download URL: $file_url"

  for sample in $(seq 1 "$SAMPLES"); do
    if speed_bps="$(curl -L --silent --show-error \
      --max-time "$TIMEOUT" \
      --output /dev/null \
      --write-out "%{speed_download}" \
      "$file_url")"; then
      speed_mbps="$(awk -v b="$speed_bps" 'BEGIN {printf "%.2f", b*8/1000/1000}')"
      speed_mib="$(awk -v b="$speed_bps" 'BEGIN {printf "%.2f", b/1024/1024}')"
      echo "  sample ${sample}: ${speed_mib} MiB/s (${speed_mbps} Mbps)"
      rates_mbps+="${speed_mbps}"$'\n'
      ((success_count += 1))
    else
      echo "  sample ${sample}: FAILED (curl error)"
    fi
  done

  read -r min_mbps avg_mbps p95_mbps count <<< "$(printf "%s" "$rates_mbps" | calc_stats)"
  if [[ "$count" == "0" ]]; then
    echo "Summary: N/A (0/${SAMPLES} successful samples)"
  else
    min_mib="$(awk -v x="$min_mbps" 'BEGIN {printf "%.2f", x*1000000/8/1048576}')"
    avg_mib="$(awk -v x="$avg_mbps" 'BEGIN {printf "%.2f", x*1000000/8/1048576}')"
    p95_mib="$(awk -v x="$p95_mbps" 'BEGIN {printf "%.2f", x*1000000/8/1048576}')"
    echo "Successful samples: ${success_count}/${SAMPLES}"
    echo "Summary Mbps (min/avg/p95): ${min_mbps} / ${avg_mbps} / ${p95_mbps}"
    echo "Summary MiB/s(min/avg/p95): ${min_mib} / ${avg_mib} / ${p95_mib}"
  fi
  echo
done

echo "Done."
