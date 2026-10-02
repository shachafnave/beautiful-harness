#!/usr/bin/env bash
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "definition-of-done: jq is not installed, so this check did not run" >&2
  exit 1
fi

input=$(cat)

active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false')
[ "$active" = "true" ] && exit 0

session=$(printf '%s' "$input" | jq -r '.session_id // "default"' | tr -c 'A-Za-z0-9_\n-' '_')
state="${TMPDIR:-/tmp}/harness-dod-${session}"
max_blocks="${HARNESS_MAX_BLOCKS:-3}"

root=$(printf '%s' "$input" | jq -r '.cwd // ""')
[ -n "$root" ] || root="${CLAUDE_PROJECT_DIR:-.}"

map_rel="${HARNESS_CODEBASE_MAP:-docs/codebase-map.md}"
ignore="${HARNESS_MAP_IGNORE:-^(\.claude/worktrees/|node_modules/)}"

git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || exit 0
top=$(git -C "$root" rev-parse --show-toplevel)
[ -f "$top/$map_rel" ] || exit 0

structural=""
map_touched=0

while IFS= read -r line; do
  [ -n "$line" ] || continue
  code=${line:0:2}
  path=${line:3}
  case "$path" in
    *' -> '*) path=${path##* -> } ;;
  esac
  path=${path#\"}
  path=${path%\"}

  if [ "$path" = "$map_rel" ]; then
    map_touched=1
    continue
  fi
  printf '%s' "$path" | grep -qE "$ignore" && continue

  case "$code" in
    *A*|*D*|*R*|'??') structural="${structural}${path}"$'\n' ;;
  esac
done <<EOF
$(git -C "$top" status --porcelain -uall)
EOF

if [ -n "$structural" ] && [ "$map_touched" -eq 0 ]; then
  blocks=$(cat "$state" 2>/dev/null || echo 0)
  if [ "$blocks" -ge "$max_blocks" ]; then
    rm -f "$state"
    echo "definition-of-done: blocked ${blocks} times in this session, letting it through. Update ${map_rel} manually." >&2
    exit 0
  fi
  echo $((blocks + 1)) > "$state"
  {
    echo "Definition of done not met: files were added, deleted, or renamed but ${map_rel} was not updated."
    echo "Add, remove, or rename the matching rows in ${map_rel}, then finish. Affected paths:"
    printf '%s' "$structural" | head -n 10 | sed 's/^/  /'
  } >&2
  exit 2
fi

rm -f "$state"
exit 0
