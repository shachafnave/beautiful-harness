---
name: fresh-review
description: "Dispatch the adversarial-reviewer agent on the current branch so a context that did not write the change tries to break it. Use before opening or merging a PR, and after fixing review findings."
---

# Fresh review

The context that produced a diff already believes it is correct. Review exists
to defeat that belief, so the reviewer must not share it.

## Steps

1. Make sure the work is committed, run `git fetch`, and note the base branch
   (the default branch from `AGENTS.md`).
2. Dispatch the `adversarial-reviewer` agent with a prompt that contains only
   the base branch name and the instruction to review the changes against
   `origin/<base>`.
   Do not include your plan, your reasoning, why you think the change is right,
   or a summary of it. If the agent type is unavailable, use `/code-review`.
3. Read the findings. Every valid objection quotes the exact line it applies to;
   discard any that do not and, if too many lack quotes, rerun the reviewer.
4. For each valid finding: fix it, and grep the source tree for the same pattern
   elsewhere (fix every instance). Log any error it exposed with `log-error`.
5. Re-run verification, push, and dispatch a new reviewer on the fixes. Repeat
   until it reports `No objections found.` or only items you can defend to the
   user as known gaps.
6. Report to the user: what the reviewer found, what was fixed, and what remains.

Never review in the authoring context, however small the diff.

## Red flags

| Thought | Reality |
| --- | --- |
| "I'll give the reviewer some context so it understands." | Your context is the belief review exists to defeat. Base branch only. |
| "This objection is wrong, I'll drop it quietly." | Defend it to the user as a known gap, or fix it. Do not drop it silently. |
| "Each round finds something new, keep going." | After two rounds of exotic findings, stop and ask whether the design is too big. Simplify, then review. |
| "The fix is one line, no need to re-review." | One-line fixes introduced regressions here before. Review the fix. |
