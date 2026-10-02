#!/usr/bin/env bash
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "no-em-dash: jq is not installed, so this check did not run" >&2
  exit 1
fi

input=$(cat)
dash=$(printf '\342\200\224')

text=$(printf '%s' "$input" | jq -r '
  [.tool_input.content, .tool_input.new_string, (.tool_input.edits[]?.new_string), .tool_input.command]
  | map(select(. != null))
  | join("\n")
')

case "$text" in
  *"$dash"*)
    target=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.command // "the tool input"' | head -n 1 | cut -c 1-80)
    echo "Blocked: em dash found in ${target}. Rewrite with a period, comma, semicolon, colon, or parentheses. En dashes stay allowed in numeric ranges." >&2
    exit 2
    ;;
esac

exit 0
