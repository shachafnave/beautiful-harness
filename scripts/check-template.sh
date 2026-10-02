#!/usr/bin/env bash
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root" || exit 1

failures=0
fail() {
  echo "FAIL $1"
  failures=$((failures + 1))
}
ok() {
  echo "ok   $1"
}

command -v jq >/dev/null 2>&1 || { echo "check-template: jq is required" >&2; exit 1; }

for f in .mcp.json .claude/settings.json; do
  if jq empty "$f" 2>/dev/null; then ok "$f is valid JSON"; else fail "$f is not valid JSON"; fi
done

if [ -L CLAUDE.md ] && [ "$(readlink CLAUDE.md)" = "AGENTS.md" ] && [ -f AGENTS.md ]; then
  ok "CLAUDE.md links to AGENTS.md"
else
  fail "CLAUDE.md is not a symlink to AGENTS.md"
fi

yaml_check=""
if python3 -c 'import yaml' 2>/dev/null; then
  yaml_check="python3"
elif ruby -e 'require "yaml"' 2>/dev/null; then
  yaml_check="ruby"
fi

frontmatter() {
  awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1 {print}' "$1"
}

valid_yaml() {
  case "$yaml_check" in
    python3) frontmatter "$1" | python3 -c 'import sys, yaml; d = yaml.safe_load(sys.stdin); sys.exit(0 if isinstance(d, dict) and d.get("name") and d.get("description") else 1)' ;;
    ruby) frontmatter "$1" | ruby -e 'require "yaml"; d = YAML.safe_load(STDIN.read); exit(d.is_a?(Hash) && d["name"] && d["description"] ? 0 : 1)' ;;
    *) return 0 ;;
  esac
}

[ -n "$yaml_check" ] || echo "skip strict YAML parsing of frontmatter (no python3 yaml or ruby)"

for d in .claude/skills/*/; do
  name=$(basename "$d")
  file="${d}SKILL.md"
  if [ ! -f "$file" ]; then fail "$name has no SKILL.md"; continue; fi
  fm_name=$(frontmatter "$file" | awk '/^name:/ {sub(/^name:[ ]*/, ""); print; exit}')
  if [ "$fm_name" = "$name" ] && valid_yaml "$file"; then ok "skill $name frontmatter"; else fail "skill $name frontmatter (name '$fm_name' or invalid YAML)"; fi
done

for file in .claude/agents/*.md; do
  name=$(basename "$file" .md)
  fm_name=$(frontmatter "$file" | awk '/^name:/ {sub(/^name:[ ]*/, ""); print; exit}')
  if [ "$fm_name" = "$name" ] && valid_yaml "$file"; then ok "agent $name frontmatter"; else fail "agent $name frontmatter (name '$fm_name' or invalid YAML)"; fi
done

for f in .claude/hooks/*.sh scripts/*.sh tests/*.sh; do
  if [ -x "$f" ]; then ok "$f is executable"; else fail "$f is not executable"; fi
  if bash -n "$f" 2>/dev/null; then ok "$f parses"; else fail "$f has a syntax error"; fi
done

wired=$(jq -r '.hooks[][].hooks[].command' .claude/settings.json)
for hook in $wired; do
  case "$hook" in
    *.sh) rel=${hook##*/}; if [ -f ".claude/hooks/$rel" ]; then ok "settings references hooks/$rel"; else fail "settings references missing hook $rel"; fi ;;
  esac
done
for f in .claude/hooks/*.sh; do
  if printf '%s\n' "$wired" | grep -q "${f##*/}"; then ok "${f##*/} is wired in settings"; else fail "${f##*/} is not wired in settings"; fi
done

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning .claude/hooks/*.sh scripts/*.sh tests/*.sh; then ok "shellcheck"; else fail "shellcheck"; fi
else
  echo "skip shellcheck (not installed)"
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
  files=$( { git -c core.quotePath=false ls-files; git -c core.quotePath=false ls-files --others --exclude-standard; } | sort -u )
else
  files=$(find . -path ./.git -prune -o -type f -print -o -type l -print | sed 's|^\./||' | sort)
fi

if [ -n "$files" ]; then ok "found $(printf '%s\n' "$files" | wc -l | tr -d ' ') repo files to scan"; else fail "no repo files found to scan"; fi

dash=$(printf '\342\200\224')
hits=$(printf '%s\n' "$files" | while IFS= read -r f; do
  [ -f "$f" ] && [ ! -L "$f" ] && grep -l "$dash" "$f" 2>/dev/null
done)
if [ -z "$hits" ]; then ok "no em dashes in repo files"; else fail "em dashes in: $hits"; fi

pattern='ruec|supabase|railway|sheetjs|cjpowqjjzuymuxpmthsq|up\.railway\.app|/Users/'
leaks=$(printf '%s\n' "$files" | grep -v -e '^LICENSE$' -e '^scripts/check-template.sh$' | while IFS= read -r f; do
  [ -f "$f" ] && [ ! -L "$f" ] && grep -liE "$pattern" "$f" 2>/dev/null
done)
if [ -z "$leaks" ]; then ok "no project-specific leftovers"; else fail "project-specific text in: $leaks"; fi

map=docs/codebase-map.md
unmapped=$(printf '%s\n' "$files" | while IFS= read -r f; do
  [ "$f" = "$map" ] && continue
  grep -qF "\`${f}\`" "$map" && continue
  dir=$f
  covered=0
  while :; do
    dir=$(dirname "$dir")
    [ "$dir" = "." ] && break
    if grep -qF "\`${dir}/\`" "$map"; then covered=1; break; fi
  done
  [ "$covered" -eq 1 ] || echo "$f"
done)
if [ -z "$unmapped" ]; then ok "every file has a row in $map"; else fail "files without a map row: $unmapped"; fi

stale=$(grep -oE '`[^` ]+\.[A-Za-z0-9]+`|`\.[A-Za-z0-9_.-]+`' "$map" | tr -d '`' | sort -u | while IFS= read -r p; do
  [ -e "$p" ] || [ -L "$p" ] || echo "$p"
done)
if [ -z "$stale" ]; then ok "no stale rows in $map"; else fail "map rows for missing files: $stale"; fi

if bash tests/hooks.test.sh >/dev/null 2>&1; then ok "hook tests"; else fail "hook tests"; fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fresh="$tmp/fresh dir"
mkdir -p "$fresh"
git -C "$fresh" init -q -b main
printf 'node_modules' > "$fresh/.gitignore"
if bash scripts/bootstrap.sh "$fresh" >/dev/null 2>&1; then ok "bootstrap into a fresh repo"; else fail "bootstrap into a fresh repo"; fi
if [ -L "$fresh/CLAUDE.md" ] && [ -x "$fresh/.claude/hooks/no-em-dash.sh" ] && [ -f "$fresh/docs/codebase-map.md" ]; then ok "bootstrap output layout"; else fail "bootstrap output layout"; fi
if grep -q "Template repo only" "$fresh/docs/codebase-map.md"; then fail "bootstrap left the template-only map section"; else ok "bootstrap stripped the template-only map section"; fi
if grep -qx "node_modules" "$fresh/.gitignore" && grep -qx ".env" "$fresh/.gitignore"; then ok "bootstrap keeps an unterminated .gitignore line intact"; else fail "bootstrap corrupted .gitignore"; fi

printf 'custom\n' > "$fresh/AGENTS.md"
printf '{"mine":true}\n' > "$fresh/.mcp.json"
printf '{"custom":true}\n' > "$fresh/.claude/settings.json"
out=$(bash scripts/bootstrap.sh --force "$fresh" 2>&1)
if [ "$(cat "$fresh/.mcp.json")" = '{"mine":true}' ] && [ "$(cat "$fresh/.claude/settings.json")" = '{"custom":true}' ]; then ok "bootstrap --force never overwrites settings.json or .mcp.json"; else fail "bootstrap --force overwrote merge-only files"; fi
case "$out" in *"hooks are copied but NOT active"*) ok "bootstrap warns when hooks are not wired" ;; *) fail "bootstrap did not warn about unwired hooks" ;; esac
printf 'custom\n' > "$fresh/AGENTS.md"
bash scripts/bootstrap.sh "$fresh" >/dev/null 2>&1
if [ "$(cat "$fresh/AGENTS.md")" = "custom" ]; then ok "bootstrap does not clobber without --force"; else fail "bootstrap clobbered AGENTS.md"; fi

real="$tmp/real-claude"
mkdir -p "$real"
printf 'my rules\n' > "$real/CLAUDE.md"
bash scripts/bootstrap.sh "$real" >/dev/null 2>&1
if [ ! -e "$real/AGENTS.md" ] && [ "$(cat "$real/CLAUDE.md")" = "my rules" ]; then ok "bootstrap leaves an existing real CLAUDE.md alone"; else fail "bootstrap mishandled an existing CLAUDE.md"; fi

outside="$tmp/outside.md"
printf 'outside\n' > "$outside"
linked="$tmp/linked"
mkdir -p "$linked/docs"
ln -s "$outside" "$linked/docs/mcp.md"
bash scripts/bootstrap.sh --force "$linked" >/dev/null 2>&1
if [ "$(cat "$outside")" = "outside" ]; then ok "bootstrap --force does not write through symlinks"; else fail "bootstrap wrote through a symlink"; fi

if bash scripts/bootstrap.sh --forse "$tmp" >/dev/null 2>&1; then fail "bootstrap accepted an unknown option"; else ok "bootstrap rejects unknown options"; fi

echo
if [ "$failures" -eq 0 ]; then echo "all checks passed"; else echo "${failures} check(s) failed"; fi
[ "$failures" -eq 0 ]
