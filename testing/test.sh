#!/bin/bash

# ============================================================
# Application Availability Test
# ============================================================
#
# Purpose:
#   Basic smoke test for a deployed frontend and backend.
#
# Usage:
#   ./test-application.sh <FRONTEND_URL> <BACKEND_URL>
#
# Example:
#   ./test-application.sh \
#       https://frontend.example.com \
#       https://backend.example.com/health
#
# Exit codes:
#   0 = frontend and backend are available
#   1 = frontend or backend is unavailable
#
# The script retries requests because Kubernetes pods may need
# some time to start after deployment.
# ============================================================

set -u

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

FRONTEND_URL="${1:-}"
BACKEND_URL="${2:-}"

MAX_ATTEMPTS=30
WAIT_SECONDS=2
CURL_TIMEOUT=5

# ------------------------------------------------------------
# Check arguments
# ------------------------------------------------------------

if [ -z "$FRONTEND_URL" ] || [ -z "$BACKEND_URL" ]; then
    echo "Usage:"
    echo "  $0 <FRONTEND_URL> <BACKEND_URL>"
    echo
    echo "Example:"
    echo "  $0 http://localhost:8080 http://localhost:9000"
    exit 1
fi

# ------------------------------------------------------------
# Test function
# ------------------------------------------------------------

test_application() {
    local name="$1"
    local url="$2"

    echo
    echo "Testing $name..."
    echo "URL: $url"

    for ((attempt=1; attempt<=MAX_ATTEMPTS; attempt++)); do

        if curl \
            --fail \
            --silent \
            --show-error \
            --max-time "$CURL_TIMEOUT" \
            "$url" > /dev/null; then

            echo "✓ $name is available"
            return 0
        fi

        echo "  Attempt $attempt/$MAX_ATTEMPTS failed."

        if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
            echo "  Waiting ${WAIT_SECONDS}s..."
            sleep "$WAIT_SECONDS"
        fi
    done

    echo "✗ $name is NOT available"
    return 1
}

# ------------------------------------------------------------
# Run tests
# ------------------------------------------------------------

frontend_failed=0
backend_failed=0

test_application "Frontend" "$FRONTEND_URL" || frontend_failed=1

test_application "Backend" "$BACKEND_URL" || backend_failed=1

# ------------------------------------------------------------
# Result
# ------------------------------------------------------------

echo
echo "======================================"
echo " Application Availability Test"
echo "======================================"

if [ "$frontend_failed" -eq 0 ]; then
    echo "✓ Frontend: PASS"
else
    echo "✗ Frontend: FAIL"
fi

if [ "$backend_failed" -eq 0 ]; then
    echo "✓ Backend:  PASS"
else
    echo "✗ Backend:  FAIL"
fi

echo "======================================"

if [ "$frontend_failed" -eq 0 ] && [ "$backend_failed" -eq 0 ]; then
    echo "✓ Overall test: PASS"
    exit 0
else
    echo "✗ Overall test: FAIL"
    exit 1
fi