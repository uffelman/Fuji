#!/usr/bin/env bash
set -euo pipefail

workflows_dir=".github/workflows"

if [[ ! -d "$workflows_dir" ]]; then
  exit 0
fi

violations=0

for workflow in "$workflows_dir"/*.yml "$workflows_dir"/*.yaml; do
  [[ -e "$workflow" ]] || continue

  has_pr_trigger=0
  has_self_hosted=0

  if rg -n "^[[:space:]]*pull_request_target([[:space:]]*:|[[:space:]]*$)|^[[:space:]]*pull_request([[:space:]]*:|[[:space:]]*$)" "$workflow" >/dev/null; then
    has_pr_trigger=1
  fi

  if rg -n "runs-on:[[:space:]]*\[[^\]]*self-hosted|runs-on:[[:space:]]*self-hosted" "$workflow" >/dev/null; then
    has_self_hosted=1
  fi

  if [[ "$has_pr_trigger" -eq 1 && "$has_self_hosted" -eq 1 ]]; then
    echo "Error: $workflow defines pull_request/pull_request_target and self-hosted runner usage." >&2
    echo "Split release/self-hosted jobs into workflows that are not triggered by PR events." >&2
    violations=1
  fi
done

exit "$violations"
