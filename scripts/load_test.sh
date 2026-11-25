#!/usr/bin/env bash
# Generate CPU load through the load balancer to trigger Auto Scaling.
#
# Usage: ./scripts/load_test.sh <app_url> [concurrency] [duration_seconds]
# Example: ./scripts/load_test.sh http://my-alb-123.ap-south-1.elb.amazonaws.com 40 600
#
# Watch: EC2 > Auto Scaling Groups > Activity, and the CloudWatch dashboard.
# Scale-out usually starts a few minutes after average CPU passes the target.
set -euo pipefail

URL="${1:?Usage: $0 <app_url> [concurrency] [duration_seconds]}"
CONCURRENCY="${2:-30}"
DURATION="${3:-600}"
URL="${URL%/}"

echo "Load testing ${URL}/cpu with ${CONCURRENCY} workers for ${DURATION}s (Ctrl+C to stop)"

end=$((SECONDS + DURATION))
pids=()

worker() {
  while [ "$SECONDS" -lt "$end" ]; do
    curl -s -o /dev/null --max-time 10 "${URL}/cpu" || true
  done
}

cleanup() { kill "${pids[@]}" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

for _ in $(seq 1 "$CONCURRENCY"); do
  worker &
  pids+=($!)
done

wait
echo "Done."
