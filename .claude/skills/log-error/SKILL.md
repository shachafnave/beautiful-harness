---
name: log-error
description: Search docs/error-log.md for a known error, then log a new or recurring one with symptom, cause, resolution, and prevention. Use when a build, lint, type, runtime, data-layer, or deploy error appears, and again when it is resolved.
---

# Log error

`docs/error-log.md` exists so no error is debugged twice.

## Before debugging

Search the log for the exact error text and for the likely cause:

```bash
grep -n -i "<distinctive part of the error>" docs/error-log.md
```

If an entry matches, apply its **Resolution** instead of re-deriving it.

## After resolving

1. If the error is already logged, do not add a second entry. Append a dated
   note to the existing one saying it recurred, and strengthen its
   **Prevention** line. A recurrence means the prevention was insufficient.
2. Otherwise add a new entry at the top of the **Log** section, newest first,
   in the shape defined at the top of the file:
   - **Where:** file, command, or screen.
   - **Symptom:** the exact error text, verbatim, in a code block.
   - **Cause:** what was actually wrong, not what it looked like.
   - **Resolution:** what changed, with file paths.
   - **Prevention:** the guard that stops it recurring, or `none`.
3. Log it even when the fix was trivial or self-inflicted. Skip only pure typos
   caught within seconds.
4. If a prevention is possible and cheap (a test, a lint rule, a hook, a line in
   `AGENTS.md`), do it in the same change and name it in **Prevention**.

The date heading uses a colon, never an em dash: `### 2026-05-04: short summary`.
