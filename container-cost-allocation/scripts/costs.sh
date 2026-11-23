#!/usr/bin/env bash
# Print the cost per namespace, per team, and per team with idle shared.
# Needs the port-forward from the README (API on localhost:9003), curl, jq.
set -euo pipefail

API=${API:-http://localhost:9003}
MINUTES=${MINUTES:-15}
END=$(date +%s)
START=$((END - MINUTES * 60))

# One row per allocation: name, CPU request, CPU used, USD per 730-hour month.
FILTER='.data[0] | to_entries | sort_by(-.value.totalCost)[]
  | [.key,
     (.value.cpuCoreRequestAverage * 1000 | round | tostring + "m"),
     (.value.cpuCoreUsageAverage * 1000 | round | tostring + "m"),
     (.value.totalCost / .value.minutes * 43800 | round | tostring)]
  | @tsv'

table() {
  echo "== $1"
  shift
  { printf 'NAME\tCPU_REQUEST\tCPU_USED\tUSD_PER_MONTH\n'
    curl -sfG "$API/allocation/compute" -d "window=$START,$END" "$@" \
      | jq -r "$FILTER"; } | column -t -s $'\t'
  echo
}

table "Cost per namespace (idle on its own line)" \
  -d aggregate=namespace -d includeIdle=true
table "Cost per team label (idle on its own line)" \
  -d aggregate=label:team -d includeIdle=true
table "Cost per team label (idle shared)" \
  -d aggregate=label:team -d includeIdle=true -d shareIdle=true
