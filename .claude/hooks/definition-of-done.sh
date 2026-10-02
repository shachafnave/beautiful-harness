#!/usr/bin/env bash
set -u
set -f

if ! command -v jq >/dev/null 2>&1; then
  echo "definition-of-done: jq is not installed, so this check did not run" >&2
  exit 1
fi

input=$(cat)

active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)
root=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null || true)
[ -n "$root" ] || root="${CLAUDE_PROJECT_DIR:-.}"

session=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null | tr -c 'A-Za-z0-9_-' '_')
[ -n "$session" ] || session=$(printf '%s' "$root" | cksum | cut -d' ' -f1)
state="${TMPDIR:-/tmp}/harness-dod-${session}"
max_blocks="${HARNESS_MAX_BLOCKS:-3}"

if [ "$active" = "true" ]; then
  rm -f "$state"
  exit 0
fi

map_rel="${HARNESS_CODEBASE_MAP:-docs/codebase-map.md}"
ignore="${HARNESS_MAP_IGNORE:-(^|/)node_modules/|^\.claude/worktrees/}"

git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || exit 0
top=$(git -C "$root" rev-parse --show-toplevel)
map="$top/$map_rel"
[ -f "$map" ] || exit 0

has_row() {
  local path=$1 dir
  grep -qF "\`${path}\`" "$map" && return 0
  dir=$path
  while [ "$dir" != "." ] && [ "$dir" != "/" ] && [ -n "$dir" ]; do
    dir=$(dirname "$dir")
    [ "$dir" = "." ] && break
    grep -qF "\`${dir}/\`" "$map" && return 0
  done
  return 1
}

problems=""

while IFS= read -r line; do
  [ -n "$line" ] || continue
  code=${line:0:2}
  path=${line:3}
  case "$path" in
    *' -> '*) path=${path##* -> } ;;
  esac

  [ "$path" = "$map_rel" ] && continue
  printf '%s' "$path" | grep -qE "$ignore" && continue

  case "$code" in
    *D*)
      if grep -qF "\`${path}\`" "$map"; then
        problems="${problems}${path} (deleted, row still in the map)"$'\n'
      fi
      ;;
    *A*|*R*|'??')
      if ! has_row "$path"; then
        problems="${problems}${path} (added, no row in the map)"$'\n'
      fi
      ;;
  esac
done <<EOF
$(git -c core.quotePath=false -C "$top" status --porcelain -uall)
EOF

if [ -n "$problems" ]; then
  blocks=$(cat "$state" 2>/dev/null || echo 0)
  if [ "$blocks" -ge "$max_blocks" ]; then
    rm -f "$state"
    echo "definition-of-done: blocked ${blocks} times in this session, letting it through. Update ${map_rel} manually." >&2
    exit 0
  fi
  echo $((blocks + 1)) > "$state"
  {
    echo "Definition of done not met: ${map_rel} does not match the files changed in the working tree."
    echo "Give each added or renamed file a row (path in backticks), and remove the rows of deleted files. Problems:"
    printf '%s' "$problems" | head -n 10 | sed 's/^/  /'
  } >&2
  exit 2
fi

rm -f "$state"
exit 0
