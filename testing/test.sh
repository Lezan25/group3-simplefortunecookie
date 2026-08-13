#!/bin/bash

FRONTEND_URL="${1:-http://localhost:8080}"
BACKEND_URL="${2:-http://localhost:9000}"

MAX_ATTEMPTS=10
WAIT_SECONDS=2

test_health() {
    NAME="$1"
    URL="$2/healthz"

    echo "Testing $NAME: $URL"

    for ((i=1; i<=MAX_ATTEMPTS; i++)); do
        if curl --fail --silent "$URL" > /dev/null; then
            echo "$NAME is healthy"
            return 0
        fi

        echo "$NAME not ready, retrying..."
        sleep "$WAIT_SECONDS"
    done

    echo "$NAME health check failed"
    return 1
}

test_health "Frontend" "$FRONTEND_URL" || exit 1
test_health "Backend" "$BACKEND_URL" || exit 1

echo "Application availability test passed!"
exit 0