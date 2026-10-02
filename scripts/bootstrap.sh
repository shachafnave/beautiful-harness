#!/usr/bin/env bash
set -eu

usage() {
  echo "Usage: scripts/bootstrap.sh <target-project-dir> [--force]" >&2
  exit 1
}

[ $# -ge 1 ] || usage
target=$1
force=0
[ "${2:-}" = "--force" ] && force=1

src=$(cd "$(dirname "$0")/.." && pwd)

[ -d "$target" ] || { echo "bootstrap: $target is not a directory" >&2; exit 1; }
target=$(cd "$target" && pwd)

if [ "$target" = "$src" ]; then
  echo "bootstrap: target is the template itself" >&2
  exit 1
fi

copied=0
skipped=0

copy_file() {
  local rel=$1
  local from="$src/$rel"
  local to="$target/$rel"
  mkdir -p "$(dirname "$to")"
  if [ -e "$to" ] || [ -L "$to" ]; then
    if [ "$force" -eq 0 ]; then
      echo "skip   $rel (exists)"
      skipped=$((skipped + 1))
      return
    fi
  fi
  cp -p "$from" "$to"
  echo "copy   $rel"
  copied=$((copied + 1))
}

files="
AGENTS.md
.mcp.json
.claude/settings.json
.claude/hooks/no-em-dash.sh
.claude/hooks/protect-main.sh
.claude/hooks/definition-of-done.sh
.claude/hooks/session-start.sh
.claude/skills/deploy/SKILL.md
.claude/skills/mockup-round/SKILL.md
.claude/skills/log-error/SKILL.md
.claude/skills/fresh-review/SKILL.md
.claude/agents/adversarial-reviewer.md
.github/pull_request_template.md
docs/error-log.md
docs/design-guidelines.md
docs/mcp.md
mockups/README.md
"

for rel in $files; do
  copy_file "$rel"
done

map_to="$target/docs/codebase-map.md"
if [ -e "$map_to" ] && [ "$force" -eq 0 ]; then
  echo "skip   docs/codebase-map.md (exists)"
  skipped=$((skipped + 1))
else
  mkdir -p "$target/docs"
  awk '/^## Template repo only$/ {exit} {print}' "$src/docs/codebase-map.md" > "$map_to"
  echo "copy   docs/codebase-map.md (template-only section removed)"
  copied=$((copied + 1))
fi

if [ -e "$target/CLAUDE.md" ] || [ -L "$target/CLAUDE.md" ]; then
  echo "skip   CLAUDE.md (exists)"
  skipped=$((skipped + 1))
else
  ln -s AGENTS.md "$target/CLAUDE.md"
  echo "link   CLAUDE.md -> AGENTS.md"
  copied=$((copied + 1))
fi

chmod +x "$target"/.claude/hooks/*.sh

gitignore="$target/.gitignore"
touch "$gitignore"
for line in ".claude/settings.local.json" ".claude/worktrees/" ".env" ".env.*"; do
  grep -qxF "$line" "$gitignore" || echo "$line" >> "$gitignore"
done

echo
echo "${copied} copied, ${skipped} skipped."

if ! command -v jq >/dev/null 2>&1; then
  echo "WARNING: jq is not installed. The hooks need it (brew install jq / apt-get install jq)."
fi

echo
echo "Placeholders left to fill in:"
(cd "$target" && grep -rnE '<<[A-Z_]+>>' AGENTS.md docs 2>/dev/null) || echo "  none"

if [ "$skipped" -gt 0 ]; then
  echo
  echo "Skipped files already existed. Merge them by hand, or re-run with --force to overwrite."
fi
