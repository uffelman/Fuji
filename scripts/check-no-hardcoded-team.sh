#!/usr/bin/env bash
set -euo pipefail

project_file="Fuji.xcodeproj/project.pbxproj"

find_disallowed_assignments_file() {
  local file="$1"
  awk '
    /DEVELOPMENT_TEAM[[:space:]]*=/ {
      if ($0 !~ /DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*""[[:space:]]*;/) {
        print FNR ":" $0
        found = 1
      }
    }
    END { exit found ? 0 : 1 }
  ' "$file"
}

find_disallowed_assignments_stdin() {
  awk '
    /DEVELOPMENT_TEAM[[:space:]]*=/ {
      if ($0 !~ /DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*""[[:space:]]*;/) {
        print NR ":" $0
        found = 1
      }
    }
    END { exit found ? 0 : 1 }
  '
}

usage() {
  echo "Usage: $0 [--repo|--staged]" >&2
}

check_repo() {
  if [[ ! -f "$project_file" ]]; then
    exit 0
  fi

  if find_disallowed_assignments_file "$project_file" >/dev/null; then
    echo "Error: hard-coded DEVELOPMENT_TEAM found in $project_file" >&2
    echo "Only DEVELOPMENT_TEAM = \"\" is allowed." >&2
    exit 1
  fi
}

check_staged() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: this check must run inside a git repository." >&2
    exit 2
  fi

  if ! git diff --cached --name-only -- "$project_file" | grep -q "^$project_file$"; then
    exit 0
  fi

  if git show ":$project_file" | find_disallowed_assignments_stdin >/dev/null; then
    echo "Error: staged changes include hard-coded DEVELOPMENT_TEAM in $project_file" >&2
    echo "Only DEVELOPMENT_TEAM = \"\" is allowed." >&2
    exit 1
  fi
}

mode="${1:---repo}"
case "$mode" in
  --repo)
    check_repo
    ;;
  --staged)
    check_staged
    ;;
  *)
    usage
    exit 2
    ;;
esac
