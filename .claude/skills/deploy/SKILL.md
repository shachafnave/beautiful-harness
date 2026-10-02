---
name: deploy
description: Ship the current branch to production. Verifies, gets an independent review, opens a PR to the default branch and merges it, which triggers the project's deploy. Use when the user says /deploy, "deploy this", or "ship it".
---

# Deploy

Read the **Commands** table in `AGENTS.md` first. The deploy target and default
branch are defined there. Deploying means getting the current branch merged into
the default branch; the project's CI or host builds and releases from it.
Invoking `/deploy` is the user's explicit instruction to merge.

## Steps

1. **Commit and push.** Everything on the working branch is committed and
   pushed. No em dashes and no code comments in the diff.
2. **Verify locally.** Run the install, build, lint, and test commands from the
   Commands table. Lint warnings that predate the change are fine; errors are
   not. If a step fails for a reason that is already in `docs/error-log.md`,
   apply the logged fix. Otherwise log the new error with the `log-error` skill.
3. **Data and schema gate.** If the diff adds a database migration, a schema
   file, or any change that must be applied to a live system outside the
   deploy, stop and tell the user what must be applied and when (before or
   after the merge). Do not merge until they confirm.
4. **Independent review.** Run the `fresh-review` skill against the default
   branch. Fix what it finds, re-verify, push, and review the fixes again.
   Report any remaining known gaps to the user.
5. **Open the PR** to the default branch using the pull request template, with
   a short description of the change, the review outcome, and known gaps.
6. **Merge** with squash, passing the full 40-character head SHA as the
   expected head so a push that landed after review cannot slip in.
7. **Report** the PR link, the merge SHA, and what to check on the live system.
   If a host or CI connector is available, check the latest deployment status
   and logs and report them.
8. **Reset the branch.** After the merge, restart the working branch from the
   new default branch before any follow-up work.
