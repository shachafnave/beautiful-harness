#!/usr/bin/env bash
set -u

root="${CLAUDE_PROJECT_DIR:-.}"
log="$root/docs/error-log.md"

echo "Working methods are in AGENTS.md. Read them before starting."

[ -f "$log" ] || exit 0

entries=$(awk '/^## Log$/ {f=1; next} f && /^### / {print}' "$log")

if [ -z "$entries" ]; then
  echo "docs/error-log.md has no entries yet. Log every error you hit, with its resolution."
  exit 0
fi

count=$(printf '%s\n' "$entries" | wc -l | tr -d ' ')
echo "Search docs/error-log.md before debugging anything (${count} logged). Newest entries:"
printf '%s\n' "$entries" | head -n 5 | sed 's/^### /  - /'
exit 0
