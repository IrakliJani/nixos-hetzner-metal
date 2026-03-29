#!/usr/bin/env bash
set -euo pipefail

# Hetzner latency tester (ICMP + optional TCP/TLS + optional hops)
# Usage examples:
#   ./hetzner-latency-compare.sh
#   ./hetzner-latency-compare.sh hel1 fsn1
#   ./hetzner-latency-compare.sh -c 50 --tcp-samples 8 --hops hel1 fsn1
#   ./hetzner-latency-compare.sh --all

PING_COUNT=30
TCP_SAMPLES=5
CURL_TIMEOUT=15
RUN_ALL=0
SHOW_HOPS=0
MAX_HOPS=20

usage() {
  cat <<'EOF'
Usage: hetzner-latency-compare.sh [options] [regions...]

Regions:
  nbg1 fsn1 hel1 ash hil sin

Options:
  -c, --count <N>         ICMP ping packet count (default: 30)
      --tcp-samples <N>   TCP/TLS samples via curl range request (default: 5)
      --curl-timeout <S>  Timeout for each TCP sample (default: 15)
      --hops              Include traceroute hop output
      --max-hops <N>      Traceroute max hops to print (default: 20)
      --all               Test all regions
  -h, --help              Show this help

Examples:
  ./hetzner-latency-compare.sh hel1 fsn1
  ./hetzner-latency-compare.sh -c 50 --tcp-samples 8 --hops hel1 fsn1
  ./hetzner-latency-compare.sh --all
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
      printf "%.3f %.3f %.3f %d", a[1], s/NR, a[p95i], NR
    }
  '
}

regions=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--count)
      [[ -n "${2:-}" ]] || { echo "--count requires a value" >&2; exit 1; }
      PING_COUNT="$2"; shift 2 ;;
    --tcp-samples)
      [[ -n "${2:-}" ]] || { echo "--tcp-samples requires a value" >&2; exit 1; }
      TCP_SAMPLES="$2"; shift 2 ;;
    --curl-timeout)
      [[ -n "${2:-}" ]] || { echo "--curl-timeout requires a value" >&2; exit 1; }
      CURL_TIMEOUT="$2"; shift 2 ;;
    --hops)
      SHOW_HOPS=1; shift ;;
    --max-hops)
      [[ -n "${2:-}" ]] || { echo "--max-hops requires a value" >&2; exit 1; }
      MAX_HOPS="$2"; shift 2 ;;
    --all)
      RUN_ALL=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      regions+=("$1"); shift ;;
  esac
done

for num_opt in PING_COUNT TCP_SAMPLES CURL_TIMEOUT MAX_HOPS; do
  val="${!num_opt}"
  [[ "$val" =~ ^[0-9]+$ ]] || { echo "${num_opt} must be an integer" >&2; exit 1; }
done

(( PING_COUNT >= 1 )) || { echo "--count must be >= 1" >&2; exit 1; }
(( TCP_SAMPLES >= 0 )) || { echo "--tcp-samples must be >= 0" >&2; exit 1; }
(( CURL_TIMEOUT >= 1 )) || { echo "--curl-timeout must be >= 1" >&2; exit 1; }
(( MAX_HOPS >= 1 )) || { echo "--max-hops must be >= 1" >&2; exit 1; }

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

echo "Testing latency for regions: ${regions[*]}"
echo "ICMP count: ${PING_COUNT} | TCP samples: ${TCP_SAMPLES} | curl timeout: ${CURL_TIMEOUT}s"
[[ "$SHOW_HOPS" -eq 1 ]] && echo "Traceroute: enabled (max hops ${MAX_HOPS})"
echo

for site in "${regions[@]}"; do
  host="${HOSTS[$site]}"

  echo "=============================="
  echo "Region: $site ($host)"
  echo "=============================="

  # ICMP latency stats
  ping_out="$(ping -c "$PING_COUNT" "$host" 2>/dev/null || true)"
  if printf '%s' "$ping_out" | grep -q "packets transmitted"; then
    loss="$(printf '%s' "$ping_out" | awk -F',' '/packets transmitted/ {gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')"
    icmp_times="$(printf '%s' "$ping_out" | awk -F'time=' '/time=/{print $2}' | awk '{print $1}')"
    read -r icmp_min icmp_avg icmp_p95 icmp_n <<< "$(printf "%s\n" "$icmp_times" | sed '/^$/d' | calc_stats)"

    if [[ "$icmp_n" == "0" ]]; then
      echo "ICMP RTT (ms): unavailable"
    else
      echo "ICMP RTT ms (min/avg/p95): ${icmp_min} / ${icmp_avg} / ${icmp_p95}"
      echo "Packet loss: ${loss:-N/A}"
    fi
  else
    echo "ICMP RTT: failed"
  fi

  # TCP/TLS/TTFB stats using HTTPS range request
  if (( TCP_SAMPLES > 0 )); then
    conn_ms=""
    tls_ms=""
    ttfb_ms=""
    tcp_url="https://${host}/100MB.bin"

    for _ in $(seq 1 "$TCP_SAMPLES"); do
      timing="$(curl -r 0-0 -o /dev/null -sS -L \
        --max-time "$CURL_TIMEOUT" \
        -w '%{time_connect} %{time_appconnect} %{time_starttransfer}\n' \
        "$tcp_url" || true)"

      if [[ -n "$timing" ]]; then
        c="$(printf '%s' "$timing" | awk '{printf "%.3f", $1*1000}')"
        a="$(printf '%s' "$timing" | awk '{printf "%.3f", $2*1000}')"
        s="$(printf '%s' "$timing" | awk '{printf "%.3f", $3*1000}')"
        conn_ms+="${c}"$'\n'
        tls_ms+="${a}"$'\n'
        ttfb_ms+="${s}"$'\n'
      fi
    done

    read -r cmin cavg cp95 cn <<< "$(printf "%s" "$conn_ms" | sed '/^$/d' | calc_stats)"
    read -r amin aavg ap95 an <<< "$(printf "%s" "$tls_ms" | sed '/^$/d' | calc_stats)"
    read -r smin savg sp95 sn <<< "$(printf "%s" "$ttfb_ms" | sed '/^$/d' | calc_stats)"

    if [[ "$cn" == "0" ]]; then
      echo "TCP/TLS/TTFB: unavailable"
    else
      echo "TCP connect ms (min/avg/p95): ${cmin} / ${cavg} / ${cp95}"
      echo "TLS done ms   (min/avg/p95): ${amin} / ${aavg} / ${ap95}"
      echo "TTFB ms       (min/avg/p95): ${smin} / ${savg} / ${sp95}"
      echo "TCP sample URL: ${tcp_url}"
    fi
  fi

  if [[ "$SHOW_HOPS" -eq 1 ]]; then
    echo "Traceroute (first ${MAX_HOPS} hops):"
    traceroute -n -w 1 -q 1 "$host" 2>/dev/null | head -n $((MAX_HOPS + 1)) || true
  fi

  echo
done

echo "Done."
