#!/usr/bin/env bash
# Repo-root gate-test harness (issue-7 §7 / survey gap 4 — this repo had no
# tests/ directory at all before this issue). Thin orchestration over each
# plugin's own self-contained test file (§2-§5); test logic itself lives in
# exactly one place, the plugin that owns it.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$HERE/.." && pwd -P)"

PLUGIN_TESTS=(
  "incident-response-proposal-order-gate/tests/order-gate.test.sh"
  "incident-response-proposal-evidence-gate/tests/evidence-gate.test.sh"
  "incident-response-rca-method-gate/tests/rca-method-gate.test.sh"
  "incident-response-action-item-gate/tests/action-item-gate.test.sh"
)

overall_rc=0
for rel in "${PLUGIN_TESTS[@]}"; do
  path="$ROOT/$rel"
  echo "== $rel =="
  if [ ! -f "$path" ]; then
    echo "MISSING: $path" >&2
    overall_rc=1
    continue
  fi
  if ! bash "$path"; then
    overall_rc=1
  fi
  echo
done

if [ "$overall_rc" -eq 0 ]; then
  echo "== all plugin gate-test suites passed =="
else
  echo "== one or more plugin gate-test suites FAILED ==" >&2
fi
exit "$overall_rc"
