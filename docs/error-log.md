# Error log

Every error hit while working on this repo, with its resolution. Build failures,
lint failures, type errors, runtime exceptions, data-layer and permission
errors, deploy failures, and anything that cost more than a moment to diagnose.

**The point is recurrence.** Before debugging anything, search this file first.
If the error has been seen before, the fix is already written down. An error
fixed but not logged will be rediscovered from scratch.

## How to add an entry

Newest entries at the top of the log. One entry per distinct error, using this
shape:

```markdown
### YYYY-MM-DD: One-line description

- **Where:** file, command, or screen where it surfaced
- **Symptom:** the exact error text, verbatim, in a code block
- **Cause:** what was actually wrong (not what it looked like)
- **Resolution:** what changed, with file paths
- **Prevention:** the guard that stops it recurring, or `none` if there isn't one
```

A worked example:

```markdown
### 2026-03-14: install fails with 403 on a pinned tarball URL

- **Where:** package install step in a sandboxed cloud session.
- **Symptom:**
  ```
  error 403 Forbidden - GET https://cdn.example.com/lib-1.2.3.tgz
  ```
- **Cause:** the dependency is pinned to a CDN host that the session's egress policy blocks. Nothing was wrong with the lockfile.
- **Resolution:** installed with the dependency temporarily removed and restored both manifest files with `git checkout` before committing.
- **Prevention:** none from the repo side; do not retry a policy 403. Run the full install locally or in CI where the host is reachable.
```

If the same error recurs after being logged, do not add a second entry. Append a
dated note to the existing one and strengthen its **Prevention** line. A
recurrence means the prevention was insufficient.

Log the error even when the fix is trivial and even when the error was
self-inflicted. Do not log errors that are pure typos caught within seconds.

## Log

### 2026-10-03: protect-main checks the session repo, not the repo the command targets

- **Where:** `.claude/hooks/protect-main.sh`, a session in `beautiful-harness` committing in `~/Code/Projects/harness-testbed`.
- **Symptom:**
  ```
  Blocked: changing history on protected branch main. Create a feature branch first.
  ```
  The testbed was on branch `setup`; only the session repo was on `main`.
- **Cause:** the hook read the branch once from the hook input `cwd` and ignored `cd X &&` and `git -C X`. That false-blocked commits in other repos on feature branches and let commits into another repo's `main` through when the session repo was on a feature branch.
- **Resolution:** when a command makes exactly one directory change and it is a leading `cd X &&` (or `cd X;`) or a `git -C X` on the history command itself, the hook checks the branch of `X` instead of the session repo. Every other command is checked against the session repo, as before.
- **Prevention:** the cross-repo tests in `tests/hooks.test.sh`. This is a starter template, so the hook stays small: a fuller shell parser was tried and dropped after four review rounds kept finding exotic bypasses.
- **Known limits:** a command with more than one directory change (`cd a && cd b`) is checked against the session repo, `pushd`, `GIT_DIR=`, `--git-dir`, quoted paths with spaces, subshells, and git hidden behind `if`, `env`, `command`, or backticks are not followed. The hook is a guard rail against accidents, not a security boundary; branch protection on the remote is the real one.
