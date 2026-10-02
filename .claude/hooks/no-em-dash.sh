#!/usr/bin/env bash
set -u

input=$(cat)
dash=$(printf '\342\200\224')

if ! command -v jq >/dev/null 2>&1; then
  case "$input" in
    *"$dash"*|*'\u2014'*|*'\U2014'*)
      echo "Blocked: em dash in tool input, and jq is not installed so the check cannot narrow it down. Install jq (brew install jq or apt-get install jq)." >&2
      exit 2
      ;;
  esac
  echo "no-em-dash: jq is not installed, so this check is only a coarse fallback" >&2
  exit 1
fi

text=$(printf '%s' "$input" | jq -r '
  def strs: if type == "string" then . else empty end;
  .tool_input as $t
  | [
      ($t.content? | strs),
      ($t.new_string? | strs),
      ($t.new_source? | strs),
      ($t.edits[]? | .new_string? | strs),
      (if .tool_name == "Bash" then ($t.command? | strs | select(test("git .*(commit|tag|notes)|gh (pr|issue|release)"))) else empty end)
    ]
  | join("\n")
') || {
  echo "no-em-dash: could not parse hook input" >&2
  exit 2
}

case "$text" in
  *"$dash"*)
    target=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.command // "the tool input"' | head -n 1 | cut -c 1-80)
    echo "Blocked: em dash found in ${target}. Rewrite with a period, comma, semicolon, colon, or parentheses. En dashes stay allowed in numeric ranges." >&2
    exit 2
    ;;
esac

exit 0
