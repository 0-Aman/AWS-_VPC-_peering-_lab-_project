#!/usr/bin/env bash

set -Eeuo pipefail

run_test() {
  local label="$1"
  local target="$2"
  local command="$3"
  printf '\n[%s] %s\n' "$label" "$command"
  if ssh -o BatchMode=yes -o ConnectTimeout=10 "$target" "$command"; then
    printf '[PASS] %s\n' "$label"
  else
    printf '[FAIL] %s\n' "$label" >&2
    exit 1
  fi
}

run_test "App-A identity" ewb-app-a "hostname && hostname -I"
run_test "App-B identity" ewb-app-b "hostname && hostname -I"
run_test "App-A to App-B" ewb-app-a "ping -c 4 -W 2 10.20.1.10"
run_test "App-B to App-A" ewb-app-b "ping -c 4 -W 2 10.10.2.10"
run_test "SSH through bastion" ewb-app-b "hostname -I | tr ' ' '\\n' | grep -Fxq 10.20.1.10"
