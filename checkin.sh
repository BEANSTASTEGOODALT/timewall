
#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TIMEWALL_COOKIE:-}" || -z "${TIMEWALL_CSRF:-}" ]]; then
    echo "Missing Timewall credentials."
    exit 1
fi

mkdir -p data
response_file=$(mktemp)
trap 'rm -f "$response_file"' EXIT

http_code=$(curl --silent --show-error \
    --output "$response_file" \
    --write-out "%{http_code}" \
    --request POST \
    "https://timewall.io/daily-streak/check-in" \
    --header "accept: application/json, text/javascript, */*; q=0.01" \
    --header "cache-control: no-cache" \
    --header "pragma: no-cache" \
    --header "x-requested-with: XMLHttpRequest" \
    --header "x-csrf-token: ${TIMEWALL_CSRF}" \
    --header "cookie: ${TIMEWALL_COOKIE}")

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if jq -e . "$response_file" >/dev/null 2>&1; then
    jq -c \
        --arg timestamp "$timestamp" \
        --arg http_status "$http_code" \
        '{timestamp: $timestamp, http_status: $http_status, response: .}' \
        "$response_file" >> data/history.jsonl

    success=$(jq -r '.success // false' "$response_file")

    if [[ "$success" == "true" ]]; then
        echo "Accepted!"
    else
        echo "success=false. Ignoring until the next scheduled run."
    fi
else
    echo "Invalid JSON response. Recording raw response."
    jq -cn \
        --arg timestamp "$timestamp" \
        --arg http_status "$http_code" \
        --rawfile response "$response_file" \
        '{timestamp: $timestamp, http_status: $http_status, response_text: $response}' \
        >> data/history.jsonl
fi
