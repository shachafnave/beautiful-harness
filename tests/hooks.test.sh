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
export TMPDIR="$tmp"
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null

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

mkrepo() {
  mkdir -p "$1"
  git -C "$1" init -q -b main
  git -C "$1" config user.name test
  git -C "$1" config user.email test@example.com
  git -C "$1" config commit.gpgsign false
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

notebook_json() {
  jq -n --arg c "$1" '{tool_name:"NotebookEdit",tool_input:{notebook_path:"n.ipynb",new_source:$c}}'
}

bash_json() {
  jq -n --arg c "$1" --arg d "${2:-$tmp}" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}'
}

expect "em dash blocked in Write content" 2 "$(run no-em-dash.sh "$(write_json "a ${dash} b")")"
expect "em dash blocked in Edit new_string" 2 "$(run no-em-dash.sh "$(edit_json "a ${dash} b")")"
expect "em dash blocked in MultiEdit second edit" 2 "$(run no-em-dash.sh "$(multi_json "a ${dash} b")")"
expect "em dash blocked in NotebookEdit" 2 "$(run no-em-dash.sh "$(notebook_json "a ${dash} b")")"
expect "em dash blocked in commit message" 2 "$(run no-em-dash.sh "$(bash_json "git commit -m \"fix ${dash} thing\"")")"
expect "em dash blocked in PR body" 2 "$(run no-em-dash.sh "$(bash_json "gh pr create --body \"fix ${dash} thing\"")")"
expect "grep for the character is allowed" 0 "$(run no-em-dash.sh "$(bash_json "grep -rn ${dash} docs")")"
expect "removing an em dash with Edit is allowed" 0 "$(run no-em-dash.sh "$(jq -n --arg o "a ${dash} b" '{tool_name:"Edit",tool_input:{file_path:"f",old_string:$o,new_string:"a, b"}}')")"
expect "en dash allowed in numeric range" 0 "$(run no-em-dash.sh "$(write_json "pages 1${endash}5")")"
expect "plain text allowed" 0 "$(run no-em-dash.sh "$(write_json "hello, world")")"
expect "tool input without text allowed" 0 "$(run no-em-dash.sh '{"tool_name":"Read","tool_input":{"file_path":"a"}}')"
expect "non-string content does not crash the hook" 0 "$(run no-em-dash.sh '{"tool_name":"Write","tool_input":{"content":["a"]}}')"
expect "malformed input fails closed" 2 "$(run no-em-dash.sh 'not json')"

repo="$tmp/repo"
mkrepo "$repo"

pm() {
  run protect-main.sh "$(bash_json "$1" "$repo")"
}

expect "first commit on empty main allowed" 0 "$(pm 'git commit -m first')"
git -C "$repo" commit -q --allow-empty -m first

expect "commit on main blocked" 2 "$(pm 'git commit -m change')"
expect "commit with -C option on main blocked" 2 "$(pm 'git -C . commit -m change')"
expect "commit with -c option on main blocked" 2 "$(pm 'git -c user.name=a commit -m change')"
expect "commit inside bash -c on main blocked" 2 "$(pm 'bash -c "git commit -m change"')"
expect "cherry-pick on main blocked" 2 "$(pm 'git cherry-pick abc123')"
expect "revert on main blocked" 2 "$(pm 'git revert HEAD')"
expect "non-ff merge on main blocked" 2 "$(pm 'git merge feat')"
expect "ff-only merge on main allowed" 0 "$(pm 'git merge --ff-only origin/main')"
expect "pull on main allowed" 0 "$(pm 'git pull --ff-only')"
expect "branch then commit in one command allowed" 0 "$(pm 'git checkout -b feat && git commit -m change')"
expect "commit then branch on main blocked" 2 "$(pm 'git commit -m x && git checkout -b y')"
expect "commit message mentioning checkout -b on main blocked" 2 "$(pm 'git commit -m "fix checkout -b bug"')"
expect "echo of a commit command on main allowed" 0 "$(pm 'echo "do not git commit here"')"
expect "bare push on main blocked" 2 "$(pm 'git push')"
expect "push origin on main blocked" 2 "$(pm 'git push origin')"
expect "push origin HEAD on main blocked" 2 "$(pm 'git push origin HEAD')"
expect "push -u origin HEAD on main blocked" 2 "$(pm 'git push -u origin HEAD')"
expect "push HEAD to another branch from main allowed" 0 "$(pm 'git push origin HEAD:feature/x')"
expect "push origin main blocked" 2 "$(pm 'git push origin main')"
expect "push -u origin main blocked" 2 "$(pm 'git push -u origin main')"
expect "push HEAD:main blocked" 2 "$(pm 'git push origin HEAD:main')"
expect "push to refs/heads/master blocked" 2 "$(pm 'git push origin HEAD:refs/heads/master')"
expect "quoted main blocked" 2 "$(pm 'git push origin "main"')"
expect "quoted HEAD:main blocked" 2 "$(pm "git push origin 'HEAD:main'")"
expect "push with -C option blocked" 2 "$(pm 'git -C . push origin main')"
expect "push inside bash -c blocked" 2 "$(pm 'bash -c "git push origin main"')"
expect "push --all blocked" 2 "$(pm 'git push --all')"
expect "push --mirror blocked" 2 "$(pm 'git push --mirror')"
expect "force push blocked" 2 "$(pm 'git push --force origin feat')"
expect "short force flag blocked" 2 "$(pm 'git push -f origin feat')"
expect "combined -fu flag blocked" 2 "$(pm 'git push -fu origin feat')"
expect "combined -uf flag blocked" 2 "$(pm 'git push -uf origin feat')"
expect "+refspec blocked" 2 "$(pm 'git push origin +feat')"
expect "trailing --force blocked" 2 "$(pm 'git push origin feat --force')"
expect "non-git command allowed" 0 "$(pm 'ls -la')"
expect "git status allowed on main" 0 "$(pm 'git status')"
expect "commit message mentioning a push rule allowed" 0 "$(pm 'git checkout -b f && git commit -m "explain git push origin main rules"')"
expect "echo of a push command allowed" 0 "$(pm 'echo git push origin main')"

git -C "$repo" checkout -q -b feature/x
expect "commit on feature branch allowed" 0 "$(pm 'git commit -m change')"
expect "commit message mentioning a push rule on a feature branch allowed" 0 "$(pm 'git commit -m "explain git push origin main rules"')"
expect "commit message mentioning force allowed" 0 "$(pm 'git commit -m "docs: git push --force is blocked"')"
expect "push feature branch allowed" 0 "$(pm 'git push -u origin feature/x')"
expect "bare push on feature branch allowed" 0 "$(pm 'git push')"
expect "push branch named like main prefix allowed" 0 "$(pm 'git push origin main-fix')"
expect "force-with-lease on feature branch allowed" 0 "$(pm 'git push --force-with-lease origin feature/x')"
expect "push to main from feature branch blocked" 2 "$(pm 'git push origin main')"

other="$tmp/other"
mkrepo "$other"
git -C "$other" commit -q --allow-empty -m first
expect "cd into a repo on main then commit blocked" 2 "$(pm "cd $other && git commit -m change")"
expect "cd with a semicolon into a repo on main then commit blocked" 2 "$(pm "cd $other; git commit -m change")"
expect "git -C a repo on main then commit blocked" 2 "$(pm "git -C $other commit -m change")"
expect "relative cd into a repo on main then commit blocked" 2 "$(pm "cd ../other && git commit -m change")"
expect "cd into a repo on main then bare push blocked" 2 "$(pm "cd $other && git push")"
expect "cd inside bash -c into a repo on main then commit blocked" 2 "$(pm "bash -c \"cd $other && git commit -m change\"")"
git -C "$other" checkout -q -b feature/y
git -C "$repo" checkout -q main
expect "cd into a repo on a feature branch then commit allowed" 0 "$(pm "cd $other && git commit -m change")"
expect "git -C a repo on a feature branch then commit allowed" 0 "$(pm "git -C $other commit -m change")"
expect "git -C commit elsewhere does not move a plain commit on main" 2 "$(pm "git -C $other commit -m x && git commit -m y")"
expect "git -C push elsewhere does not move an earlier commit on main" 2 "$(pm "git commit -m y && git -C $other push")"
expect "git -C commit elsewhere does not move a bare push on main" 2 "$(pm "git -C $other commit -m x; git push")"
expect "git -C elsewhere does not move a later commit on main" 2 "$(pm "git -C $other status && git commit -m change")"
expect "git -C elsewhere does not move a later bare push on main" 2 "$(pm "git -C $other fetch && git push")"
expect "commit in session repo on main after cd elsewhere and back blocked" 2 "$(pm "cd $other && cd $repo && git commit -m change")"
git -C "$repo" checkout -q feature/x

mainr="$tmp/mainr"
mkrepo "$mainr"
git -C "$mainr" commit -q --allow-empty -m first
mkdir -p "$mainr/sub"
pmm() {
  run protect-main.sh "$(bash_json "$1" "$mainr")"
}
expect "failed cd then commit on main blocked" 2 "$(pmm 'cd nonexist; git commit -m x')"
expect "cd - then commit on main blocked" 2 "$(pmm 'cd - && git commit -m x')"
expect "cd to command substitution then commit on main blocked" 2 "$(pmm 'cd $(git rev-parse --show-toplevel) && git commit -m x')"
expect "cd with a flag then commit on main blocked" 2 "$(pmm 'cd -P . && git commit -m x')"
expect "git -C an unresolvable path on main blocked" 2 "$(pmm 'git -C /no/such/dir commit -m x')"
expect "switch -c then commit on main allowed" 0 "$(pmm 'git switch -c tmp && git commit -m x')"
git -C "$mainr" branch dev
expect "cd away and cd - back to main then commit blocked" 2 "$(pmm "cd $other && cd - && git commit -m x")"
expect "cd inside command substitution then commit on main blocked" 2 "$(pmm "x=\$(cd $other && pwd); git commit -m x")"
expect "checkout files from a branch then commit on main blocked" 2 "$(pmm 'git checkout dev -- README && git commit -m x')"
expect "quoted heredoc marker does not hide later lines" 2 "$(pmm "$(printf "echo '<<EOF' >> notes\ngit commit -m x")")"
expect "heredoc fed to bash is checked" 2 "$(pmm "$(printf 'bash <<EOF\ngit commit -m x\nEOF')")"
expect "heredoc fed to sh -s is checked" 2 "$(pmm "$(printf 'sh -s <<EOF\ngit commit -m x\nEOF')")"
expect "here-string does not hide later lines" 2 "$(pmm "$(printf 'cat <<< \"msg\"\ngit push origin main')")"
expect "commit in command substitution after an assignment blocked" 2 "$(pmm 'x=$(git commit -m y)')"
expect "command after a heredoc is still checked" 2 "$(pmm "$(printf 'cat > notes.txt <<EOF\nhello\nEOF\ngit commit -m x')")"

custom_out=$(printf '%s' "$(bash_json 'git push origin feat' "$repo")" | HARNESS_PROTECTED_BRANCHES="main develop " "$hooks/protect-main.sh" >/dev/null 2>&1; echo $?)
expect "trailing space in HARNESS_PROTECTED_BRANCHES is harmless" 0 "$custom_out"
custom_out=$(printf '%s' "$(bash_json 'git push origin develop' "$repo")" | HARNESS_PROTECTED_BRANCHES="main develop " "$hooks/protect-main.sh" >/dev/null 2>&1; echo $?)
expect "custom protected branch blocked" 2 "$custom_out"
expect "malformed input fails closed" 2 "$(run protect-main.sh 'not json')"

stop_json() {
  jq -n --arg d "$1" --argjson a "${2:-false}" '{hook_event_name:"Stop",cwd:$d,stop_hook_active:$a,session_id:"dod"}'
}

dod="$tmp/dod"
mkrepo "$dod"
mkdir -p "$dod/docs"
printf '# map\n' > "$dod/docs/codebase-map.md"
git -C "$dod" add -A
git -C "$dod" commit -q -m init

expect "clean tree passes Stop" 0 "$(run definition-of-done.sh "$(stop_json "$dod")")"

printf 'x\n' > "$dod/new-file.txt"
expect "new file without a row blocks Stop" 2 "$(run definition-of-done.sh "$(stop_json "$dod")")"
expect "stop_hook_active bypasses the block" 0 "$(run definition-of-done.sh "$(stop_json "$dod" true)")"

printf '\n' >> "$dod/docs/codebase-map.md"
expect "touching the map without a row still blocks" 2 "$(run definition-of-done.sh "$(stop_json "$dod")")"

printf '| `new-file.txt` | x |\n' >> "$dod/docs/codebase-map.md"
expect "new file with its row passes Stop" 0 "$(run definition-of-done.sh "$(stop_json "$dod")")"

git -C "$dod" add -A
git -C "$dod" commit -q -m "add file"
git -C "$dod" rm -q new-file.txt
expect "deleted file whose row remains blocks Stop" 2 "$(run definition-of-done.sh "$(stop_json "$dod")")"
git -C "$dod" reset -q --hard

mkdir -p "$dod/pkg/sub"
printf 'x\n' > "$dod/pkg/sub/a.txt"
expect "file in an unlisted directory blocks Stop" 2 "$(run definition-of-done.sh "$(stop_json "$dod")")"
printf '| `pkg/` | everything in pkg |\n' >> "$dod/docs/codebase-map.md"
expect "directory row covers files below it" 0 "$(run definition-of-done.sh "$(stop_json "$dod")")"
rm -rf "$dod/pkg"

printf 'two\n' >> "$dod/new-file.txt"
expect "modification alone does not block" 0 "$(run definition-of-done.sh "$(stop_json "$dod")")"
git -C "$dod" checkout -q -- new-file.txt

mkdir -p "$dod/node_modules/pkg" "$dod/sub/node_modules/pkg"
printf 'z\n' > "$dod/node_modules/pkg/index.js"
printf 'z\n' > "$dod/sub/node_modules/pkg/index.js"
expect "node_modules at any depth does not block" 0 "$(run definition-of-done.sh "$(stop_json "$dod")")"
rm -rf "$dod/node_modules" "$dod/sub"

printf 'x\n' > "$dod/caf$(printf '\303\251').txt"
expect "non-ascii file name without a row blocks Stop" 2 "$(run definition-of-done.sh "$(stop_json "$dod")")"
printf '| `caf%s.txt` | x |\n' "$(printf '\303\251')" >> "$dod/docs/codebase-map.md"
expect "non-ascii file name with its row passes Stop" 0 "$(run definition-of-done.sh "$(stop_json "$dod")")"
rm -f "$dod/caf"*.txt

loop="$tmp/loop"
mkrepo "$loop"
mkdir -p "$loop/docs"
printf '# map\n' > "$loop/docs/codebase-map.md"
git -C "$loop" add -A
git -C "$loop" commit -q -m init
printf 'x\n' > "$loop/new.txt"
loop_json=$(jq -n --arg d "$loop" '{hook_event_name:"Stop",cwd:$d,session_id:"loop-test"}')
active_json=$(jq -n --arg d "$loop" '{hook_event_name:"Stop",cwd:$d,session_id:"loop-test",stop_hook_active:true}')
expect "loop guard: first block" 2 "$(run definition-of-done.sh "$loop_json")"
expect "loop guard: second block" 2 "$(run definition-of-done.sh "$loop_json")"
expect "loop guard: third block" 2 "$(run definition-of-done.sh "$loop_json")"
expect "loop guard: lets it through after the cap" 0 "$(run definition-of-done.sh "$loop_json")"
expect "loop guard: counter resets after release" 2 "$(run definition-of-done.sh "$loop_json")"
expect "loop guard: continuation stop passes and resets" 0 "$(run definition-of-done.sh "$active_json")"
expect "loop guard: enforcement continues after a reset" 2 "$(run definition-of-done.sh "$loop_json")"

nomap="$tmp/nomap"
mkrepo "$nomap"
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

methods_proj="$tmp/methods"
mkdir -p "$methods_proj"
printf '# P\n\n## Working methods\n\n1. **RULE ONE.** Body.\n\n### Red flags\n\n| a | b |\n\n### Next section\n\nNOT PRINTED\n' > "$methods_proj/AGENTS.md"
session_out=$(CLAUDE_PROJECT_DIR="$methods_proj" "$hooks/session-start.sh" 2>&1)
case "$session_out" in
  *"RULE ONE"*"| a | b |"*) expect "session-start prints the working methods and red flags" 0 0 ;;
  *) expect "session-start prints the working methods and red flags" 0 1 ;;
esac
case "$session_out" in
  *"NOT PRINTED"*) expect "session-start stops at the next section" 0 1 ;;
  *) expect "session-start stops at the next section" 0 0 ;;
esac
session_out=$(CLAUDE_PROJECT_DIR="$root" "$hooks/session-start.sh" 2>&1)
case "$session_out" in
  *"NO DONE CLAIM WITHOUT FRESH EVIDENCE"*"The build passes, so it works"*) expect "session-start prints methods and red flags from the shipped AGENTS.md" 0 0 ;;
  *) expect "session-start prints methods and red flags from the shipped AGENTS.md" 0 1 ;;
esac
case "$session_out" in
  *"Keep the codebase map current"*) expect "session-start stops before the codebase map section of the shipped AGENTS.md" 0 1 ;;
  *) expect "session-start stops before the codebase map section of the shipped AGENTS.md" 0 0 ;;
esac
fallback_proj="$tmp/fallback"
mkdir -p "$fallback_proj"
session_out=$(CLAUDE_PROJECT_DIR="$fallback_proj" "$hooks/session-start.sh" 2>&1)
case "$session_out" in
  *"Working methods are in AGENTS.md"*) expect "session-start falls back to a pointer without AGENTS.md" 0 0 ;;
  *) expect "session-start falls back to a pointer without AGENTS.md" 0 1 ;;
esac

echo
echo "${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
