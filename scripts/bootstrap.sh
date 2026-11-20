#!/usr/bin/env bash
set -eu

usage() {
  echo "Usage: scripts/bootstrap.sh [--force] <target-project-dir>" >&2
  exit 1
}

force=0
target=""
for arg in "$@"; do
  case "$arg" in
    --force) force=1 ;;
    -*) echo "bootstrap: unknown option $arg" >&2; usage ;;
    *)
      [ -z "$target" ] || usage
      target=$arg
      ;;
  esac
done
[ -n "$target" ] || usage

src=$(cd "$(dirname "$0")/.." && pwd)

[ -d "$target" ] || { echo "bootstrap: $target is not a directory" >&2; exit 1; }
target=$(cd "$target" && pwd)

if [ "$target" = "$src" ]; then
  echo "bootstrap: target is the template itself" >&2
  exit 1
fi

copied=0
skipped=0
settings_skipped=0
agents_skipped=0
lock_skipped=0
license_skipped=0
vendored_skipped=""
vendored_skills="animate apple-design break-ui emil-design-eng review-animations"

copy_file() {
  local rel=$1 merge_only=${2:-0}
  local from="$src/$rel"
  local to="$target/$rel"
  mkdir -p "$(dirname "$to")"
  if [ -L "$to" ]; then
    echo "skip   $rel (is a symlink)"
    skipped=$((skipped + 1))
    return
  fi
  if [ -e "$to" ]; then
    if [ "$merge_only" -eq 1 ] || [ "$force" -eq 0 ]; then
      echo "skip   $rel (exists)"
      skipped=$((skipped + 1))
      if [ "$rel" = ".claude/settings.json" ]; then
        settings_skipped=1
      fi
      if [ "$rel" = "skills-lock.json" ]; then
        lock_skipped=1
      fi
      if [ "$rel" = "THIRD_PARTY_LICENSES.md" ]; then
        license_skipped=1
      fi
      return
    fi
  fi
  cp -p "$from" "$to"
  echo "copy   $rel"
  copied=$((copied + 1))
}

copy_dir() {
  local rel=$1
  local from="$src/$rel"
  local to="$target/$rel"
  if [ -e "$to" ] || [ -L "$to" ]; then
    echo "skip   $rel/ (exists)"
    skipped=$((skipped + 1))
    vendored_skipped="$vendored_skipped ${rel##*/}"
    return
  fi
  mkdir -p "$(dirname "$to")"
  cp -pR "$from" "$to"
  echo "copy   $rel/"
  copied=$((copied + 1))
}

files="
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

copy_file .claude/settings.json 1
copy_file .mcp.json 1

for name in $vendored_skills; do
  copy_dir ".claude/skills/$name"
done
copy_file skills-lock.json 1
copy_file THIRD_PARTY_LICENSES.md 1

if [ -f "$target/CLAUDE.md" ] && [ ! -L "$target/CLAUDE.md" ] && [ ! -e "$target/AGENTS.md" ]; then
  echo "skip   AGENTS.md (a real CLAUDE.md exists)"
  echo "skip   CLAUDE.md"
  skipped=$((skipped + 2))
  agents_skipped=1
else
  copy_file AGENTS.md
  if [ -e "$target/CLAUDE.md" ] || [ -L "$target/CLAUDE.md" ]; then
    echo "skip   CLAUDE.md (exists)"
    skipped=$((skipped + 1))
  else
    ln -s AGENTS.md "$target/CLAUDE.md"
    echo "link   CLAUDE.md -> AGENTS.md"
    copied=$((copied + 1))
  fi
fi

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

chmod +x "$target"/.claude/hooks/*.sh

gitignore="$target/.gitignore"
touch "$gitignore"
if [ -s "$gitignore" ] && [ "$(tail -c 1 "$gitignore" | wc -l | tr -d ' ')" -eq 0 ]; then
  echo >> "$gitignore"
fi
for line in ".claude/settings.local.json" ".claude/worktrees/" ".env" ".env.local" ".env.*.local"; do
  grep -qxF "$line" "$gitignore" || echo "$line" >> "$gitignore"
done

echo
echo "${copied} copied, ${skipped} skipped."

if ! command -v jq >/dev/null 2>&1; then
  echo "WARNING: jq is not installed. The hooks need it (brew install jq / apt-get install jq)."
fi

if ! git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
  echo "WARNING: $target is not a git repository. protect-main and definition-of-done do nothing until it is."
fi

if [ "$settings_skipped" -eq 1 ]; then
  echo
  echo "WARNING: .claude/settings.json already existed, so the hooks are copied but NOT active."
  echo "Merge the permissions and hooks blocks from $src/.claude/settings.json into it by hand."
fi

if [ "$agents_skipped" -eq 1 ]; then
  echo
  echo "NOTE: your CLAUDE.md was left alone. Rename it to AGENTS.md, merge the template's"
  echo "$src/AGENTS.md into it, then run: ln -s AGENTS.md CLAUDE.md"
fi

if [ -n "$vendored_skipped" ]; then
  echo
  echo "WARNING: these vendored skills already existed and were not replaced, so their pin does not hold:"
  for name in $vendored_skipped; do
    echo "  $name"
  done
fi

if [ "$lock_skipped" -eq 1 ]; then
  echo
  echo "NOTE: skills-lock.json already existed. Merge the entries from $src/skills-lock.json into it by hand."
fi

if [ "$license_skipped" -eq 1 ]; then
  echo
  echo "NOTE: THIRD_PARTY_LICENSES.md already existed. Add the MIT notice for the vendored skills from $src/THIRD_PARTY_LICENSES.md to it by hand."
fi

echo
echo "Placeholders left to fill in:"
(cd "$target" && grep -rnE '<<[A-Z_]+>>' AGENTS.md docs 2>/dev/null) || echo "  none"

if [ "$skipped" -gt 0 ]; then
  echo
  echo "Skipped files already existed. Merge them by hand, or re-run with --force to overwrite (settings.json, .mcp.json, skills-lock.json and THIRD_PARTY_LICENSES.md are never overwritten, and an existing skill folder is never replaced)."
fi
