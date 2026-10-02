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

for d in .claude/skills/*/; do
  name=$(basename "$d")
  file="$d/SKILL.md"
  if [ ! -f "$file" ]; then fail "$name has no SKILL.md"; continue; fi
  fm_name=$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} /^name:/ {sub(/^name:[ ]*/, ""); print; exit}' "$file")
  fm_desc=$(awk 'NR>1 && $0=="---" {exit} /^description:/ {print; exit}' "$file")
  if [ "$fm_name" = "$name" ] && [ -n "$fm_desc" ]; then ok "skill $name frontmatter"; else fail "skill $name frontmatter (name '$fm_name')"; fi
done

for file in .claude/agents/*.md; do
  name=$(basename "$file" .md)
  fm_name=$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} /^name:/ {sub(/^name:[ ]*/, ""); print; exit}' "$file")
  if [ "$fm_name" = "$name" ]; then ok "agent $name frontmatter"; else fail "agent $name frontmatter (name '$fm_name')"; fi
done

for f in .claude/hooks/*.sh scripts/*.sh tests/*.sh; do
  if [ -x "$f" ]; then ok "$f is executable"; else fail "$f is not executable"; fi
  if bash -n "$f" 2>/dev/null; then ok "$f parses"; else fail "$f has a syntax error"; fi
done

for hook in $(jq -r '.hooks[][].hooks[].command' .claude/settings.json); do
  rel=${hook##*/}
  if [ -f ".claude/hooks/$rel" ]; then ok "settings references hooks/$rel"; else fail "settings references missing hook $rel"; fi
done

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning .claude/hooks/*.sh scripts/*.sh tests/*.sh; then ok "shellcheck"; else fail "shellcheck"; fi
else
  echo "skip shellcheck (not installed)"
fi

dash=$(printf '\342\200\224')
tracked=$( { git ls-files; git ls-files --others --exclude-standard; } 2>/dev/null | sort -u )
hits=$(printf '%s\n' "$tracked" | while IFS= read -r f; do
  [ -f "$f" ] && [ ! -L "$f" ] && grep -l "$dash" "$f" 2>/dev/null
done)
if [ -z "$hits" ]; then ok "no em dashes in repo files"; else fail "em dashes in: $hits"; fi

pattern='ruec|supabase|railway|sheetjs|cjpowqjjzuymuxpmthsq|up\.railway\.app|/Users/'
leaks=$(printf '%s\n' "$tracked" | grep -v -e '^LICENSE$' -e '^scripts/check-template.sh$' | while IFS= read -r f; do
  [ -f "$f" ] && [ ! -L "$f" ] && grep -liE "$pattern" "$f" 2>/dev/null
done)
if [ -z "$leaks" ]; then ok "no project-specific leftovers"; else fail "project-specific text in: $leaks"; fi

if bash tests/hooks.test.sh >/dev/null 2>&1; then ok "hook tests"; else fail "hook tests"; fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git -C "$tmp" init -q -b main
if bash scripts/bootstrap.sh "$tmp" >/dev/null 2>&1; then ok "bootstrap into a fresh repo"; else fail "bootstrap into a fresh repo"; fi
if [ -L "$tmp/CLAUDE.md" ] && [ -x "$tmp/.claude/hooks/no-em-dash.sh" ] && [ -f "$tmp/docs/codebase-map.md" ]; then ok "bootstrap output layout"; else fail "bootstrap output layout"; fi
if grep -q "Template repo only" "$tmp/docs/codebase-map.md"; then fail "bootstrap left the template-only map section"; else ok "bootstrap stripped the template-only map section"; fi
printf 'custom\n' > "$tmp/AGENTS.md"
bash scripts/bootstrap.sh "$tmp" >/dev/null 2>&1
if [ "$(cat "$tmp/AGENTS.md")" = "custom" ]; then ok "bootstrap does not clobber"; else fail "bootstrap clobbered AGENTS.md"; fi

echo
if [ "$failures" -eq 0 ]; then echo "all checks passed"; else echo "${failures} check(s) failed"; fi
[ "$failures" -eq 0 ]
