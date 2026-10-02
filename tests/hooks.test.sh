#!/usr/bin/env bash
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
hooks="$root/.claude/hooks"
dash=$(printf '\342\200\224')
endash=$(printf '\342\200\223')

pass=0
fail=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

expect() {
  local name=$1 want=$2 got=$3
  if [ "$want" = "$got" ]; then
    pass=$((pass + 1))
    echo "ok   $name"
  else
    fail=$((fail + 1))
    echo "FAIL $name (want exit $want, got $got)"
  fi
}

run() {
  local hook=$1 json=$2
  printf '%s' "$json" | "$hooks/$hook" >/dev/null 2>&1
  echo $?
}

write_json() {
  jq -n --arg c "$1" '{tool_name:"Write",tool_input:{file_path:"notes.md",content:$c}}'
}

edit_json() {
  jq -n --arg c "$1" '{tool_name:"Edit",tool_input:{file_path:"notes.md",old_string:"x",new_string:$c}}'
}

multi_json() {
  jq -n --arg c "$1" '{tool_name:"MultiEdit",tool_input:{file_path:"notes.md",edits:[{old_string:"a",new_string:"fine"},{old_string:"b",new_string:$c}]}}'
}

bash_json() {
  jq -n --arg c "$1" --arg d "${2:-$tmp}" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}'
}

expect "em dash blocked in Write content" 2 "$(run no-em-dash.sh "$(write_json "a ${dash} b")")"
expect "em dash blocked in Edit new_string" 2 "$(run no-em-dash.sh "$(edit_json "a ${dash} b")")"
expect "em dash blocked in MultiEdit second edit" 2 "$(run no-em-dash.sh "$(multi_json "a ${dash} b")")"
expect "em dash blocked in commit message" 2 "$(run no-em-dash.sh "$(bash_json "git commit -m \"fix ${dash} thing\"")")"
expect "en dash allowed in numeric range" 0 "$(run no-em-dash.sh "$(write_json "pages 1${endash}5")")"
expect "plain text allowed" 0 "$(run no-em-dash.sh "$(write_json "hello, world")")"
expect "tool input without text allowed" 0 "$(run no-em-dash.sh '{"tool_name":"Read","tool_input":{"file_path":"a"}}')"

repo="$tmp/repo"
mkdir -p "$repo"
git -C "$repo" init -q -b main
git -C "$repo" config user.name test
git -C "$repo" config user.email test@example.com

expect "first commit on empty main allowed" 0 "$(run protect-main.sh "$(bash_json 'git commit -m first' "$repo")")"
git -C "$repo" commit -q --allow-empty -m first

expect "commit on main blocked" 2 "$(run protect-main.sh "$(bash_json 'git commit -m change' "$repo")")"
expect "branch then commit in one command allowed" 0 "$(run protect-main.sh "$(bash_json 'git checkout -b feat && git commit -m change' "$repo")")"
expect "bare push on main blocked" 2 "$(run protect-main.sh "$(bash_json 'git push' "$repo")")"
expect "push origin main blocked" 2 "$(run protect-main.sh "$(bash_json 'git push origin main' "$repo")")"
expect "push -u origin main blocked" 2 "$(run protect-main.sh "$(bash_json 'git push -u origin main' "$repo")")"
expect "push HEAD:main blocked" 2 "$(run protect-main.sh "$(bash_json 'git push origin HEAD:main' "$repo")")"
expect "push to refs/heads/master blocked" 2 "$(run protect-main.sh "$(bash_json 'git push origin HEAD:refs/heads/master' "$repo")")"
expect "force push blocked" 2 "$(run protect-main.sh "$(bash_json 'git push --force origin feat' "$repo")")"
expect "short force flag blocked" 2 "$(run protect-main.sh "$(bash_json 'git push -f origin feat' "$repo")")"
expect "non-git command allowed" 0 "$(run protect-main.sh "$(bash_json 'ls -la' "$repo")")"
expect "git status allowed on main" 0 "$(run protect-main.sh "$(bash_json 'git status' "$repo")")"

git -C "$repo" checkout -q -b feature/x
expect "commit on feature branch allowed" 0 "$(run protect-main.sh "$(bash_json 'git commit -m change' "$repo")")"
expect "push feature branch allowed" 0 "$(run protect-main.sh "$(bash_json 'git push -u origin feature/x' "$repo")")"
expect "push branch named like main prefix allowed" 0 "$(run protect-main.sh "$(bash_json 'git push origin main-fix' "$repo")")"
expect "force-with-lease on feature branch allowed" 0 "$(run protect-main.sh "$(bash_json 'git push --force-with-lease origin feature/x' "$repo")")"

stop_json() {
  jq -n --arg d "$1" --argjson a "${2:-false}" '{hook_event_name:"Stop",cwd:$d,stop_hook_active:$a}'
}

dod="$tmp/dod"
mkdir -p "$dod/docs"
git -C "$dod" init -q -b main
git -C "$dod" config user.name test
git -C "$dod" config user.email test@example.com
printf '# map\n' > "$dod/docs/codebase-map.md"
git -C "$dod" add -A
git -C "$dod" commit -q -m init

expect "clean tree passes Stop" 0 "$(run definition-of-done.sh "$(stop_json "$dod")")"

printf 'x\n' > "$dod/new-file.txt"
expect "new file without map change blocks Stop" 2 "$(run definition-of-done.sh "$(stop_json "$dod")")"
expect "stop_hook_active bypasses the block" 0 "$(run definition-of-done.sh "$(stop_json "$dod" true)")"

printf '# map\n| new-file.txt | x |\n' > "$dod/docs/codebase-map.md"
expect "new file with map change passes Stop" 0 "$(run definition-of-done.sh "$(stop_json "$dod")")"

git -C "$dod" add -A
git -C "$dod" commit -q -m "add file"
git -C "$dod" rm -q new-file.txt
expect "deleted file without map change blocks Stop" 2 "$(run definition-of-done.sh "$(stop_json "$dod")")"
git -C "$dod" reset -q --hard

printf 'one\n' > "$dod/tracked.txt"
printf '# map\n| tracked.txt | x |\n' > "$dod/docs/codebase-map.md"
git -C "$dod" add -A
git -C "$dod" commit -q -m "add tracked"
printf 'two\n' >> "$dod/tracked.txt"
expect "modification alone does not block" 0 "$(run definition-of-done.sh "$(stop_json "$dod")")"
git -C "$dod" checkout -q -- tracked.txt

mkdir -p "$dod/node_modules/pkg"
printf 'z\n' > "$dod/node_modules/pkg/index.js"
expect "ignored directory does not block" 0 "$(run definition-of-done.sh "$(stop_json "$dod")")"

nomap="$tmp/nomap"
mkdir -p "$nomap"
git -C "$nomap" init -q -b main
printf 'a\n' > "$nomap/a.txt"
expect "no map file means no enforcement" 0 "$(run definition-of-done.sh "$(stop_json "$nomap")")"

nogit="$tmp/nogit"
mkdir -p "$nogit"
expect "non-git directory passes Stop" 0 "$(run definition-of-done.sh "$(stop_json "$nogit")")"

session_out=$(CLAUDE_PROJECT_DIR="$dod" "$hooks/session-start.sh" 2>&1)
expect "session-start exits 0" 0 "$?"
case "$session_out" in
  *AGENTS.md*) expect "session-start mentions AGENTS.md" 0 0 ;;
  *) expect "session-start mentions AGENTS.md" 0 1 ;;
esac

log_proj="$tmp/logproj"
mkdir -p "$log_proj/docs"
printf '# Error log\n\n```markdown\n### YYYY-MM-DD: template\n```\n\n## Log\n\n### 2026-01-02: second\n\n### 2026-01-01: first\n' > "$log_proj/docs/error-log.md"
session_out=$(CLAUDE_PROJECT_DIR="$log_proj" "$hooks/session-start.sh" 2>&1)
case "$session_out" in
  *"2 logged"*"2026-01-02: second"*) expect "session-start lists entries and ignores the template block" 0 0 ;;
  *) expect "session-start lists entries and ignores the template block" 0 1 ;;
esac

echo
echo "${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
