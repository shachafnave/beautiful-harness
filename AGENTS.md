# <<PROJECT_NAME>>

<<ONE_LINE_DESCRIPTION>>

`CLAUDE.md` is a symlink to this file, so every tool (Claude Code, Codex,
Cursor, and others) reads the same guidance. If a tool-specific deviation ever
becomes necessary, replace the symlink with a real file in the commit that
introduces the deviation.

## Commands

Skills read this table. Keep it true.

| Purpose | Command |
| --- | --- |
| Install | `<<INSTALL_COMMAND>>` |
| Dev server | `<<DEV_COMMAND>>` |
| Build | `<<BUILD_COMMAND>>` |
| Lint | `<<LINT_COMMAND>>` |
| Test | `<<TEST_COMMAND>>` |
| Deploy target | `<<DEPLOY_TARGET>>` (default branch: `<<DEFAULT_BRANCH>>`) |

## Working methods

These hold for every change, alongside the code rules below. Each one opens with
its rule in capitals. Breaking the letter of a rule is breaking its spirit;
there is no reading of these that makes a skipped step acceptable.

1. **NO MULTI-PART CHANGE WITHOUT A WRITTEN PLAN.** Anything with three or
   more moving parts gets a plan first. The plan lists files touched, helpers
   needed, schema changes, and how the result will be verified, not only how it
   will be built. If the work drifts from the plan, stop and re-plan on the
   spot.
2. **ONE TASK PER SUBAGENT, AND NEVER REVIEW YOUR OWN WORK.** Research and
   exploration run in subagents, never on the main thread. Harder problems get
   more subagents, not more patience. The agent that reviews a change is never
   the agent that wrote it.
3. **EVERY CORRECTION BECOMES A WRITTEN RULE.** When the user corrects a
   mistake, add the rule to this file or a skill in the same session. Read the
   rules before a relevant task. Iterate until the mistake stops recurring.
4. **NO DONE CLAIM WITHOUT FRESH EVIDENCE.** Self-review confirms assumptions;
   it does not test them. A passing build and lint is not a working feature.
   Run the real flow, and have a fresh-context reviewer try to break the
   change. Every objection the reviewer raises quotes the exact line it applies
   to.
5. **DEMAND ELEGANCE, IN PROPORTION.** On a real change, pause and ask whether
   there is a cleaner way. Keep simple, obvious fixes simple, with no extra
   ceremony. Challenge the work before calling it finished.
6. **A BUG REPORT IS ENOUGH TO START.** Read the logs, the error, and the
   failing check, then resolve it. Do not push context switching back to the
   user.

### Red flags

If you catch yourself thinking one of these, stop and follow the method.

| Thought | Reality |
| --- | --- |
| "It's too small to need a plan or a review." | Small diffs hide the bugs nobody looks for. Size changes the ceremony, not the rule. |
| "The build passes, so it works." | A build proves it compiles. Run the flow you changed. |
| "I already reviewed it myself." | You review what you meant to write. A fresh context reviews what you wrote. |
| "I'll add the rule after this task." | The correction is freshest now. Write it in this session. |
| "I'll ask the user which log to read." | Read it yourself. A bug report is enough to start. |

### Keep the codebase map current

[`docs/codebase-map.md`](./docs/codebase-map.md) lists every file and what it
is for. Creating a file means adding its row in the same change; deleting or
renaming one means updating its row in the same change. A change that adds a
file without a map row is incomplete, not a follow-up. The Stop hook checks the
uncommitted changes in the working tree against the map: every added or renamed
path needs a backticked row (or a backticked parent directory row), and a
deleted path must not keep one.

### Log every error with its resolution

[`docs/error-log.md`](./docs/error-log.md) records build, lint, type, runtime,
data-layer, and deploy failures: symptom verbatim, real cause, fix, and the
guard against recurrence. Search it before debugging; a logged error has its fix
already written down. Log the error even when the fix turns out to be trivial or
self-inflicted. Use the `log-error` skill.

### Mockup before build for any new or changed UI surface

New screens, new components, and visible redesigns go through, in order:

1. **Interview.** Ask the questions that would change the design before drawing
   anything. Do not guess at intent.
2. **Mockup.** A self-contained HTML file saved as
   `mockups/<round-name>/<screen>.html`, with realistic data and the app's real
   styling. Check it against every rule in
   [`docs/design-guidelines.md`](./docs/design-guidelines.md) before presenting
   it. A mockup that breaks a guideline goes back for another pass.
3. **Approval.** The mockup is the gate. Wait for an explicit yes. Iterate on
   the mockup, not in code.
4. **Plan.** Once approved, write the implementation plan.
5. **Build.** Implement, then verify per the rules below.

Pure bug fixes, refactors, and backend-only work skip the mockup and go straight
to plan and build. Use the `mockup-round` skill.

## Code rules

- **Fix every instance, not just the reported one.** When you find a bug or a
  pattern worth changing, grep the source tree for the same pattern and fix all
  of it in the same change.
- **Fixes should make the system simpler, not more complex.** Prefer removing or
  consolidating code over adding a layer, flag, or special case. If a fix grows
  the surface area, look for the version that shrinks it.
- **Solve at the layer all paths flow through.** Before patching a call site,
  ask whether the fix belongs in the shared helper. Check for an existing helper
  before writing a new one-liner, but do not manufacture an abstraction for a
  pattern with one caller. Shared layers in this project:
  <<SHARED_LAYERS>>
- **Never use em dashes.** Not in UI copy, docs, commit messages, PR
  descriptions, or anything else written in this repo. Use a period, a comma, a
  semicolon, a colon, or parentheses, whichever the sentence needs. In tables
  and forms, an empty optional value renders blank and a missing number renders
  `n/a`. En dashes stay allowed in numeric ranges (`1–5`, `50–79%`). The
  PreToolUse hook enforces this.
- **Never leave comments in the repo.** The standard is zero comments: no
  explanatory comments or docblocks, TODO or FIXME notes, lint or type
  suppression directives, and no commented-out code. Express intent through
  names, structure, and tests; put rationale in commit messages, PR
  descriptions, or docs.
- **Never merge to `<<DEFAULT_BRANCH>>` without a fresh-context review that
  tries to break the change.** Not a blessing: hunt for the bug, the missed edge
  case, the unstated assumption, the regression. Use the `fresh-review` skill or
  `/code-review`. Never self-review in the authoring context, however small the
  diff. Resolve what the reviewer finds before merging.
- **Verify locally.** Run the build, lint, and test commands above for every
  change, plus any test covering what you changed.
- **Verify non-trivial UI changes in a running instance** before calling a
  change done. Click through the flow you changed; a passing build is not the
  same as a working feature.
- **Front-end changes ship with screenshots** of the real running app with
  realistic data (before and after for changes to something that already
  existed).

## Project notes

<<PROJECT_NOTES>>
