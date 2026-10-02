#!/usr/bin/env bash
set -u
set -f

fail_closed() {
  echo "protect-main: $1" >&2
  exit 2
}

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  case "$input" in
    *git*) fail_closed "jq is not installed, so git commands are blocked until it is (brew install jq or apt-get install jq)" ;;
    *) exit 0 ;;
  esac
fi

cmd=$(printf '%s' "$input" | jq -er '.tool_input.command // ""') || fail_closed "could not parse hook input"
[ -n "$cmd" ] || exit 0

cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
[ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-.}"

protected="${HARNESS_PROTECTED_BRANCHES:-main master}"
words=""
for p in $protected; do
  esc=$(printf '%s' "$p" | sed 's/[][\.*^$()+?{}|/]/\\&/g')
  words="${words:+$words|}$esc"
done
[ -n "$words" ] || exit 0

norm=$(printf '%s' "$cmd" | tr -d "\"'" | tr '\n' ';')

start='(^|[;&|(]|(bash|sh|zsh)[[:space:]]+-c)[[:space:]]*'
gitg='git([[:space:]]+(-C|-c)[[:space:]]+[^[:space:];&|]+|[[:space:]]+--[a-z-]+(=[^[:space:];&|]+)?)*'
gitpre="${start}${gitg}[[:space:]]+"
end='([[:space:];&|)]|$)'

block() {
  echo "Blocked: $1" >&2
  exit 2
}

branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || true)
on_protected=0
for p in $protected; do
  [ "$branch" = "$p" ] && on_protected=1
done

pushes=$(printf '%s\n' "$norm" | grep -oE "${gitpre}push([[:space:]]+[^;&|]*)?" || true)

if [ -n "$pushes" ]; then
  while IFS= read -r seg; do
    args=${seg#*push}
    if printf ' %s' "$args" | grep -qE '[[:space:]](--force|-[A-Za-z]*f[A-Za-z]*)([[:space:]]|$)'; then
      block "force pushes are not allowed. Use --force-with-lease on a feature branch if a rewrite is needed."
    fi
    if printf ' %s' "$args" | grep -qE '[[:space:]]\+[^[:space:]]'; then
      block "a +refspec is a force push. Use --force-with-lease on a feature branch if a rewrite is needed."
    fi
    if printf ' %s' "$args" | grep -qE '[[:space:]](--all|--mirror)([[:space:]]|$)'; then
      block "git push --all and --mirror touch protected branches. Push named branches instead."
    fi
    if printf ' %s' "$args" | grep -qE "(^|[[:space:]:])(refs/heads/)?(${words})([[:space:]]|\$)"; then
      block "pushing directly to a protected branch (${protected}). Push a feature branch and open a pull request."
    fi
    if [ "$on_protected" -eq 1 ]; then
      positional=""
      for tok in $args; do
        case "$tok" in
          -*) ;;
          *) positional="${positional} ${tok}" ;;
        esac
      done
      set -- $positional
      shift 2>/dev/null || true
      explicit=0
      for ref in "$@"; do
        [ "$ref" = "HEAD" ] || explicit=1
      done
      if [ "$explicit" -eq 0 ]; then
        block "git push from protected branch ${branch} without naming a different branch. Switch to a feature branch."
      fi
    fi
  done <<EOF
$pushes
EOF
fi

if [ "$on_protected" -eq 1 ]; then
  git -C "$cwd" rev-parse --verify HEAD >/dev/null 2>&1 || exit 0

  mut_re="${gitpre}(commit|cherry-pick|revert|am)${end}"
  merge_re="${gitpre}merge${end}"
  create_re="${gitpre}(checkout[[:space:]]+-[bB]|switch[[:space:]]+-[cC])${end}"

  mut_pos=$(printf '%s' "$norm" | grep -obE "$mut_re" | head -n 1 | cut -d: -f1)
  if [ -z "$mut_pos" ] && printf '%s' "$norm" | grep -qE "$merge_re" && ! printf '%s' "$norm" | grep -q -e '--ff-only'; then
    mut_pos=$(printf '%s' "$norm" | grep -obE "$merge_re" | head -n 1 | cut -d: -f1)
  fi

  if [ -n "$mut_pos" ]; then
    create_pos=$(printf '%s' "$norm" | grep -obE "$create_re" | head -n 1 | cut -d: -f1)
    if [ -n "$create_pos" ] && [ "$create_pos" -lt "$mut_pos" ]; then
      exit 0
    fi
    block "changing history on protected branch ${branch}. Create a feature branch first."
  fi
fi

exit 0
