#!/usr/bin/env bash
set -euo pipefail

# Usage: loadtest.sh <url> [duration] [availability-threshold]
URL="${1:?Usage: loadtest.sh <url> [duration] [availability-threshold]}"
DURATION="${2:-20S}"
THRESHOLD="${3:-95}"

LEVELS=(10 25 50 100 200 400)

for c in "${LEVELS[@]}"; do
  echo "=== Concurrency: $c ==="

  LOG=$(mktemp)
  docker run --rm rufus/siege-engine \
    -c "$c" -t "$DURATION" -b "$URL" > "$LOG" 2>&1

  cat "$LOG"

  AVAIL=$(grep "Availability" "$LOG" | awk '{print $2}' | tr -d '%')

  if [ -z "$AVAIL" ]; then
    echo "Could not parse availability from siege output, stopping."
    break
  fi

  echo "Availability at c=$c: ${AVAIL}%"

  if (( $(echo "$AVAIL < $THRESHOLD" | bc -l) )); then
    echo "Breaking point reached: availability dropped below ${THRESHOLD}% at concurrency $c"
    exit 0
  fi
done

echo "Survived all tested concurrency levels (${LEVELS[*]}) above ${THRESHOLD}% availability"