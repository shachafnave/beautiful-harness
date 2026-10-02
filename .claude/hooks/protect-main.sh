#!/usr/bin/env bash
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "protect-main: jq is not installed, so this check did not run" >&2
  exit 1
fi

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
[ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-.}"

protected="${HARNESS_PROTECTED_BRANCHES:-main master}"
alt=$(printf '%s' "$protected" | tr -s ' ' '|')

block() {
  echo "Blocked: $1" >&2
  exit 2
}

pushes=$(printf '%s\n' "$cmd" | grep -oE 'git[[:space:]]+push[^;&|]*' || true)

if [ -n "$pushes" ]; then
  while IFS= read -r seg; do
    if printf '%s' "$seg" | grep -qE '(^|[[:space:]])(--force|-f)([[:space:]]|$)'; then
      block "force pushes are not allowed. Use --force-with-lease on a feature branch if a rewrite is needed."
    fi
    if printf '%s' "$seg" | grep -qE "(^|[[:space:]:+])(refs/heads/)?(${alt})([[:space:]]|\$)"; then
      block "pushing directly to a protected branch (${protected}). Push a feature branch and open a pull request."
    fi
  done <<EOF
$pushes
EOF
fi

branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || true)

if [ -n "$branch" ]; then
  on_protected=0
  for p in $protected; do
    [ "$branch" = "$p" ] && on_protected=1
  done

  if [ "$on_protected" -eq 1 ]; then
    if printf '%s' "$cmd" | grep -qE '(checkout[[:space:]]+-b|switch[[:space:]]+-c)'; then
      exit 0
    fi
    if printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+push([[:space:]]*$|[[:space:]]*[;&|])'; then
      block "bare git push while on protected branch ${branch}. Switch to a feature branch."
    fi
    if git -C "$cwd" rev-parse --verify HEAD >/dev/null 2>&1; then
      if printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit'; then
        block "committing on protected branch ${branch}. Create a feature branch first."
      fi
    fi
  fi
fi

exit 0
