#!/usr/bin/env bash
set -u

hash256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  fi
}

skill_hash() {
  (cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s\n' "${f#./}"
    cat "$f"
  done) | hash256
}

frontmatter_name() {
  awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1 && /^name:/ {sub(/^name:[ ]*/, ""); print; exit}' "$1"
}

command -v jq >/dev/null 2>&1 || { echo "check-skills: jq is required" >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || { echo "check-skills: neither sha256sum nor shasum is installed" >&2; exit 2; }

if [ "${1:-}" = "--hash" ]; then
  [ -d "${2:-}" ] || { echo "Usage: scripts/check-skills.sh --hash <dir>" >&2; exit 2; }
  digest=$(skill_hash "$2")
  [ -n "$digest" ] || exit 2
  echo "$digest"
  exit 0
fi

root=${1:-$(cd "$(dirname "$0")/.." && pwd)}
lock="$root/skills-lock.json"

failures=0
fail() {
  echo "FAIL $1"
  failures=$((failures + 1))
}
ok() {
  echo "ok   $1"
}

[ -f "$lock" ] || { echo "FAIL skills-lock.json is missing"; exit 1; }
jq empty "$lock" 2>/dev/null || { echo "FAIL skills-lock.json is not valid JSON"; exit 1; }

for k in $(jq -r '.skills | keys[]' "$lock"); do
  dir="$root/.claude/skills/$k"
  if [ ! -f "$dir/SKILL.md" ]; then
    fail "skill $k: folder or SKILL.md is missing"
    continue
  fi
  name=$(frontmatter_name "$dir/SKILL.md")
  [ "$name" = "$k" ] || fail "skill $k: frontmatter name is '$name'"
  license=$(jq -r --arg k "$k" '.skills[$k].license // ""' "$lock")
  [ -n "$license" ] || fail "skill $k: license is empty"
  want=$(jq -r --arg k "$k" '.skills[$k].computedHash // ""' "$lock")
  got=$(skill_hash "$dir")
  if [ -n "$got" ] && [ "$got" = "$want" ]; then
    ok "skill $k pinned"
  else
    fail "skill $k: hash mismatch"
  fi
  if awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1 && /^disable-model-invocation:[ ]*true/ {found=1} END {exit !found}' "$dir/SKILL.md"; then
    grep -qF "/$k" "$root/AGENTS.md" 2>/dev/null || fail "skill $k is user-invoked only; AGENTS.md must tell the user to run /$k"
  fi
done

required=$(awk '/^### Required design skills$/ {f=1; next} /^#+ / {f=0} f' "$root/AGENTS.md" 2>/dev/null | awk -F'|' '$4 ~ /^ *Yes *$/ {print $3}' | grep -o '`[a-z0-9-]*`' | tr -d '`')
if [ -z "$required" ]; then
  fail "no required skills found in AGENTS.md"
else
  missing=0
  for name in $required; do
    jq -e --arg k "$name" '.skills[$k]' "$lock" >/dev/null 2>&1 || { fail "required skill $name is not in skills-lock.json"; missing=1; }
  done
  [ "$missing" -eq 0 ] && ok "required skills are pinned"
fi

[ "$failures" -eq 0 ]
