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
