# Reference app alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Vendor five design skills into the harness with a hash pin, require them in the mockup flow, and carry the reference app's newer generic rules into the template.

**Architecture:** Skills are real folders under `.claude/skills/`. A root `skills-lock.json` pins each by sha256. One new script, `scripts/check-skills.sh`, verifies the pin and is called by `scripts/check-template.sh`. Bootstrap copies skills folder-wise and never mixes files into an existing folder. Rule changes are prose edits in existing files.

**Tech Stack:** bash, git, jq. `sha256sum` or `shasum -a 256`.

**Spec:** `docs/superpowers/specs/2026-11-20-reference-app-alignment-design.md`

## Global Constraints

- No em dashes anywhere except inside the vendored skill folders listed in `skills-lock.json`.
- No comments in code or scripts.
- The origin-project leak guard in `scripts/check-template.sh` must keep passing. Never name the reference app, its stack vendors or hosting, or write an absolute home-directory path in any file. Refer to the origin only as "the reference app".
- Every added file has a row (or a backticked parent directory row) in `docs/codebase-map.md` in the same task.
- Vendored skills are copied verbatim. Never edit a file inside them.
- Skill set, exactly: `animate`, `apple-design`, `break-ui`, `emil-design-eng`, `review-animations`. `impeccable` is not vendored.
- Hash scheme: sha256 over, for each file in the folder sorted by relative path in the C locale, the relative path, a newline, then the file bytes.
- Lockfile entry fields: `source`, `sourceType`, `sourceUrl`, `skillPath`, `license`, `computedHash`. Top-level `version` is `1`.
- Guidelines override vendored skills where they conflict.
- Screenshots are committed under `docs/screenshots/<feature>/` as `before-*.png` and `after-*.png`.
- Commit only if the owner has asked for commits. Otherwise stage with `git add` and stop. Never push or merge in this plan.

## Review Focus

- Target project already has a folder named like a vendored skill (real or symlink): bootstrap skips the whole folder, leaves it untouched, and warns that the pin does not hold. Pinned by Task 2.
- A vendored file is edited by hand: the check fails and names the skill. Pinned by Task 1.
- `skills-lock.json` lists a skill whose folder is missing: the check fails. Pinned by Task 1.
- A skill marked `Yes` in the required-skills table is absent from the lockfile, or the table is missing: the check fails. Pinned by Task 3.
- Bootstrap into a path with a space, then verify the copied skills against the lock: bytes are identical. Pinned by Task 2.

---

### Task 1: Vendored skills, lockfile, licence notice, check-skills.sh

**Files:**
- Create: `.claude/skills/{animate,apple-design,break-ui,emil-design-eng,review-animations}/` (verbatim)
- Create: `skills-lock.json`, `THIRD_PARTY_LICENSES.md`, `scripts/check-skills.sh`
- Modify: `scripts/check-template.sh`, `docs/codebase-map.md`

**Interfaces:**
- Produces: `bash scripts/check-skills.sh [root]` prints `ok`/`FAIL` lines, exits non-zero on any failure, default root is the repo root. `bash scripts/check-skills.sh --hash <dir>` prints the folder's hex digest. Exits 2 with a message on stderr when neither `sha256sum` nor `shasum` exists.
- Produces: `skills-lock.json` shape `{"version":1,"skills":{"<name>":{...fields above...}}}`.

- [x] **Step 1: Create the branch.** `git switch -c feat/reference-alignment` from the current clean HEAD. Run `git status --short` and confirm only the spec, plan and map edits are present.

- [x] **Step 2: Write the failing checks in `scripts/check-template.sh`.** Insert after the `shellcheck` block:

```bash
if bash scripts/check-skills.sh >/dev/null 2>&1; then ok "vendored skills match skills-lock.json"; else fail "vendored skills do not match skills-lock.json"; fi
```

  Insert before the `dash=` line, and change the em dash `hits` loop so vendored files are skipped:

```bash
vendored=$(jq -r '.skills | keys[] | ".claude/skills/" + .' skills-lock.json 2>/dev/null)
is_vendored() {
  local d
  for d in $vendored; do
    case "$1" in "$d"/*) return 0 ;; esac
  done
  return 1
}
```

  The loop body becomes `[ -f "$f" ] && [ ! -L "$f" ] && ! is_vendored "$f" && grep -l "$dash" "$f" 2>/dev/null`.

  Insert before the final `echo` (after the `--forse` test) a tamper block, with `$tmp` already defined:

```bash
tamper="$tmp/tamper"
mkdir -p "$tamper/.claude"
cp -R .claude/skills "$tamper/.claude/skills"
cp skills-lock.json AGENTS.md "$tamper/"
printf 'x' >> "$tamper/.claude/skills/animate/SKILL.md"
if bash scripts/check-skills.sh "$tamper" >/dev/null 2>&1; then fail "check-skills accepted an edited vendored file"; else ok "check-skills rejects an edited vendored file"; fi
rm -rf "$tamper/.claude/skills/break-ui"
if bash scripts/check-skills.sh "$tamper" 2>&1 | grep -q "break-ui"; then ok "check-skills names a missing skill folder"; else fail "check-skills did not name the missing break-ui folder"; fi
```

- [x] **Step 3: Run `bash scripts/check-template.sh`.** Expected: FAIL on "vendored skills do not match skills-lock.json" (script and lock do not exist yet).

- [x] **Step 4: Copy the skills.** For each name: `cp -RL ~/.claude/skills/<name> .claude/skills/<name>` (the installed copies are symlinks, so `-L` is required). Confirm with `find .claude/skills/animate -type f` that `RECIPES.md` and `SKILL.md` are present, and that `break-ui` has `CATALOG.md`, `review-animations` has `STANDARDS.md`.

- [x] **Step 5: Write `THIRD_PARTY_LICENSES.md`.** Heading `# Third-party licenses`, a sentence naming the five skills, their source `https://github.com/emilkowalski/skills`, then the upstream MIT text fetched with `gh api repos/emilkowalski/skills/license --jq .content | base64 -d`. Confirm it has zero em dashes.

- [x] **Step 6: Implement `scripts/check-skills.sh`** (`set -u`, needs `jq`).
  - `hash256`: reads stdin, runs `sha256sum` if present else `shasum -a 256`, prints only the hex digest, else prints an error to stderr and exits 2.
  - `skill_hash <dir>`: `(cd "$dir" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do printf '%s\n' "${f#./}"; cat "$f"; done) | hash256`.
  - `--hash <dir>` mode prints `skill_hash`.
  - Verify mode, for each key `k` in `$root/skills-lock.json`: `FAIL` if `$root/.claude/skills/$k/SKILL.md` is missing (message contains `k`); `FAIL` if frontmatter `name` differs from `k`; `FAIL` if `license` is empty; `FAIL` if the recomputed hash differs from `computedHash`; otherwise `ok skill $k pinned`.
  - Exit non-zero if any failure.

- [x] **Step 7: Generate `skills-lock.json`.** For each skill write the entry with `source` `emilkowalski/skills`, `sourceType` `github`, `sourceUrl` `https://github.com/emilkowalski/skills.git`, `skillPath` `skills/<name>/SKILL.md`, `license` `MIT`, and `computedHash` from `bash scripts/check-skills.sh --hash .claude/skills/<name>`. Build it with `jq -n` so the file is valid JSON.

- [x] **Step 8: Add map rows** to `docs/codebase-map.md`: `skills-lock.json` and `THIRD_PARTY_LICENSES.md` in the Root table; one row per `.claude/skills/<name>/` folder in the `.claude/` table (purpose: vendored third-party skill, one line each, `apple-design` for Apple-style typography and motion, `emil-design-eng` for interaction polish, `animate` for building motion, `review-animations` for reviewing motion, `break-ui` for worst-case data passes); `scripts/check-skills.sh` in the Template repo only table (purpose: verifies `skills-lock.json` hashes and the required-skills table; `--hash` prints a folder hash).

- [x] **Step 9: Run `bash scripts/check-template.sh`.** Expected: `all checks passed`, including "vendored skills match", "no em dashes in repo files", "no project-specific leftovers", both tamper checks, and shellcheck clean.

- [x] **Step 10: Stage** `git add .claude/skills skills-lock.json THIRD_PARTY_LICENSES.md scripts docs`.

### Task 2: Bootstrap copies skills folder-wise

**Files:**
- Modify: `scripts/bootstrap.sh`, `scripts/check-template.sh`

**Interfaces:**
- Consumes: `skills-lock.json`, the five folders, `THIRD_PARTY_LICENSES.md`, `scripts/check-skills.sh <root>` from Task 1.
- Produces: `copy_dir <rel>` in bootstrap: copies a directory with `cp -pR` only when the target path does not exist and is not a symlink, otherwise prints `skip   <rel>/ (exists)` and records the name for the warning.

- [x] **Step 1: Write failing tests** in `scripts/check-template.sh`, after the "bootstrap output layout" check:

```bash
if [ -f "$fresh/.claude/skills/animate/RECIPES.md" ] && [ -f "$fresh/skills-lock.json" ] && [ -f "$fresh/THIRD_PARTY_LICENSES.md" ]; then ok "bootstrap copies vendored skills, lockfile and notice"; else fail "bootstrap did not copy vendored skills, lockfile or notice"; fi
if bash scripts/check-skills.sh "$fresh" >/dev/null 2>&1; then ok "bootstrapped skills match the lockfile (path with a space)"; else fail "bootstrapped skills do not match the lockfile"; fi
```

  And after the symlink test:

```bash
pre="$tmp/pre-skill"
mkdir -p "$pre/.claude/skills/animate"
printf 'mine\n' > "$pre/.claude/skills/animate/SKILL.md"
printf '{"mine":true}\n' > "$pre/skills-lock.json"
out=$(bash scripts/bootstrap.sh --force "$pre" 2>&1)
if [ "$(cat "$pre/.claude/skills/animate/SKILL.md")" = "mine" ] && [ ! -e "$pre/.claude/skills/animate/RECIPES.md" ]; then ok "bootstrap never mixes files into an existing skill folder"; else fail "bootstrap changed an existing skill folder"; fi
case "$out" in *"pin does not hold"*"animate"*) ok "bootstrap warns when a vendored skill folder existed" ;; *) fail "bootstrap did not warn about the existing animate folder" ;; esac
if [ "$(cat "$pre/skills-lock.json")" = '{"mine":true}' ]; then ok "bootstrap --force keeps an existing skills-lock.json"; else fail "bootstrap overwrote skills-lock.json"; fi
case "$out" in *"skills-lock.json already existed"*) ok "bootstrap tells the user to merge the lockfile" ;; *) fail "bootstrap did not mention the existing lockfile" ;; esac
```

  Add a list-equality check next to the frontmatter checks:

```bash
if [ "$(jq -r '.skills | keys[]' skills-lock.json | sort | tr '\n' ' ')" = "$(sed -n 's/^vendored_skills="\(.*\)"$/\1/p' scripts/bootstrap.sh | tr ' ' '\n' | sort | tr '\n' ' ')" ]; then ok "bootstrap vendored_skills matches skills-lock.json"; else fail "bootstrap vendored_skills differs from skills-lock.json"; fi
```

- [x] **Step 2: Run `bash scripts/check-template.sh`.** Expected: the new checks FAIL.

- [x] **Step 3: Implement in `scripts/bootstrap.sh`.**
  - Add `vendored_skills="animate apple-design break-ui emil-design-eng review-animations"` and `vendored_skipped=""`, `lock_skipped=0` near the other counters.
  - Add `copy_dir() { local rel=$1 ... }` per the Interfaces block; on copy print `copy   <rel>/` and increment `copied`; on skip increment `skipped` and append the skill name to `vendored_skipped`.
  - After `copy_file .mcp.json 1`: loop `for name in $vendored_skills; do copy_dir ".claude/skills/$name"; done`, then `copy_file skills-lock.json 1`, then `copy_file THIRD_PARTY_LICENSES.md`.
  - In `copy_file`, set `lock_skipped=1` when `rel` is `skills-lock.json` and it was skipped (same pattern as `settings_skipped`).
  - After the existing warnings, print when `vendored_skipped` is non-empty: `WARNING: these vendored skills already existed and were not replaced, so their pin does not hold:` followed by the names; when `lock_skipped` is 1: `NOTE: skills-lock.json already existed. Merge the entries from $src/skills-lock.json into it by hand.`
  - Change the final skipped notice to say settings.json, .mcp.json and skills-lock.json are never overwritten and existing skill folders are never replaced.

- [x] **Step 4: Run `bash scripts/check-template.sh`.** Expected: `all checks passed`.

- [x] **Step 5: Stage** `git add scripts`.

### Task 3: AGENTS.md rules, required-skills table, mockup-round, PR template

**Files:**
- Modify: `AGENTS.md`, `.claude/skills/mockup-round/SKILL.md`, `.github/pull_request_template.md`, `scripts/check-skills.sh`, `scripts/check-template.sh`

**Interfaces:**
- Consumes: `check-skills.sh <root>` from Task 1.
- Produces: in `AGENTS.md`, a `### Required design skills` section with a markdown table whose columns are `When | Skill | Required`. Skills in rows whose Required cell is exactly `Yes` must be keys in `skills-lock.json`.

- [x] **Step 1: Write failing checks** in `scripts/check-template.sh` after the tamper block:

```bash
jq 'del(.skills.animate)' skills-lock.json > "$tamper/skills-lock.json"
rm -rf "$tamper/.claude/skills/animate"
if bash scripts/check-skills.sh "$tamper" 2>&1 | grep -q "required skill animate"; then ok "check-skills rejects a required skill missing from the lockfile"; else fail "check-skills accepted a lockfile without a required skill"; fi
printf '# no table here\n' > "$tamper/AGENTS.md"
if bash scripts/check-skills.sh "$tamper" 2>&1 | grep -q "no required skills"; then ok "check-skills rejects a missing required-skills table"; else fail "check-skills accepted a missing required-skills table"; fi
```

  Run `bash scripts/check-template.sh`. Expected: both FAIL.

- [x] **Step 2: Extend `scripts/check-skills.sh` verify mode.** Take the lines of `$root/AGENTS.md` between `### Required design skills` and the next heading; for rows whose third `|` field is exactly ` Yes `, collect backticked names from the second field. `FAIL no required skills found in AGENTS.md` if none. `FAIL required skill <name> is not in skills-lock.json` for each name that is not a lock key. `ok required skills are pinned` otherwise.

- [x] **Step 3: Edit `AGENTS.md`.**
  - Commands table: add `| Demo instance | `<<DEMO_COMMAND>>` |` after the Dev server row.
  - Mockup step 2: append the sentence `Run the [required design skills](#required-design-skills) first.`
  - Add the following section immediately before `## Code rules`:

```markdown
### Required design skills

The mockup flow runs these skills, vendored in `.claude/skills/` and pinned in
`skills-lock.json`. Invoke each with the specific screen and question, never
bare: a bare call returns only a greeting. Where a skill and
[`docs/design-guidelines.md`](./docs/design-guidelines.md) disagree, the
guidelines win; the skills supply craft (type, motion, press and gesture feel),
not materials. Ignore a pointer to a skill that is not installed.

| When | Skill | Required |
| --- | --- | --- |
| Mockup step | `apple-design`, `emil-design-eng` | Yes |
| Mockup step | `impeccable` | If installed |
| Mockup shows motion (transitions, sheets, press, gestures) | `animate` | Yes |
| Before presenting the mockup | `break-ui` | Yes |
| After build, when the change includes motion | `review-animations` | Yes |

A mockup is not presented until every required row that applies has run.
```

  - Em dash bullet: append `Vendored third-party skills listed in `skills-lock.json` are kept verbatim and hash-pinned, so the template self-check skips them.`
  - Replace the "Verify non-trivial UI changes" bullet with: `**Verify non-trivial UI changes in a running instance** before calling a change done. Use the demo instance (`<<DEMO_COMMAND>>` in the Commands table: seeded data, never live data; a project with none writes `n/a` and the reason, and uses its dev instance with seed data). Click through the flow you changed; a passing build is not the same as a working feature.`
  - Replace the screenshots bullet with: `**Front-end changes ship with screenshots** of the real running app with realistic data (before and after for changes to something that already existed), committed under `docs/screenshots/<feature>/` as `before-*.png` and `after-*.png`.`
  - Add three bullets after "Verify locally": `**Rerun the full suite after every rebase.** A long-open branch rebased onto new work runs the full test suite again, not only build and lint.`; `**Schema changes are new migrations.** Never edit a migration that has been applied. Apply a new one to the live system before merging code that reads the new shape.`; `**Live data is outward-facing.** Confirm with the user before the first write to a live system, and read untrusted input files with an isolated interpreter in their own folder.`

- [x] **Step 4: Edit `.claude/skills/mockup-round/SKILL.md`.**
  - Step 2: add a bullet that the required design skills from `AGENTS.md` (Required design skills) run before drawing, each invoked with the screen and the question, never bare, with a line that the guidelines win where a skill disagrees and that pointers to skills that are not installed are ignored.
  - Step 3: add that `break-ui` runs on the mockup before it is presented, and the message states which skills ran.
  - Step 6: replace "attach before and after screenshots" with committing them under `docs/screenshots/<feature>/` (`before-*.png`, `after-*.png`), name the demo instance command, and add that `review-animations` runs when the change includes motion.
  - Red flags: add the row `"The skill says to use blur, so I will."` with reality `The guidelines win where they disagree with a skill. Use solid surfaces.`

- [x] **Step 5: Edit `.github/pull_request_template.md`.** Replace the screenshots checkbox with `- [ ] Before and after screenshots committed under `docs/screenshots/<feature>/` for any front-end change` and add `- [ ] Required design skills ran (see `AGENTS.md`) for any UI change`.

- [x] **Step 6: Run `bash scripts/check-template.sh`.** Expected: `all checks passed`, including the two new rejections and "required skills are pinned". Run `bash tests/hooks.test.sh` and confirm it passes.

- [x] **Step 7: Stage** `git add AGENTS.md .claude .github scripts`.

### Task 4: Design guidelines

**Files:**
- Modify: `docs/design-guidelines.md`, `README.md`, `docs/codebase-map.md`

- [x] **Step 1: Edit `docs/design-guidelines.md`.**
  - Intro: add a paragraph after the first: `The vendored design skills (see **Required design skills** in `AGENTS.md`) supply craft: type, motion, press and gesture feel. They do not override these rules. Where a skill recommends something a rule here forbids (blurred translucent layers, gradient scroll masks), the rule wins.`
  - Replace rule 2 with: `2. No decorative icons. Icons appear only on action buttons, always as one set beside the button's label and in the button's own text color. Never put icons on cards, headings, feature blocks, or empty states. Elsewhere use typographic glyphs (`+`, arrows, asterisks), numbers, or no icons at all.`
  - Append to rule 10: `Sizes come from one scale in `rem`, with tighter tracking as size grows.`
  - Add after rule 30: `31. Every action control has a press state. A short scale or tint change on `:active`, switched off under `prefers-reduced-motion`. A control that looks the same pressed and unpressed reads as broken.`
  - Append to the closing section: `Where a rule can be checked by scanning source (no raw color values outside tokens, no gradients, no colored side stripes, a press state on every action class, text sizes from the scale), write it as a test in the project. Mechanical guards catch regressions a mockup check cannot see.`

- [x] **Step 2: Update counts.** In `README.md` ("Thirty rules") and `docs/codebase-map.md` (design-guidelines row) change to "Thirty-one rules". Run `grep -rn "Thirty rules" . --include=*.md` and confirm no hits.

- [x] **Step 3: Run `bash scripts/check-template.sh`.** Expected: `all checks passed`.

- [x] **Step 4: Stage** `git add docs README.md`.

### Task 5: README and codebase map corrections

**Files:**
- Modify: `README.md`, `docs/codebase-map.md`

- [x] **Step 1: Edit `README.md`.**
  - "What is in the box": add rows for the vendored design skills (`.claude/skills/{animate,apple-design,break-ui,emil-design-eng,review-animations}`, `skills-lock.json`, `THIRD_PARTY_LICENSES.md`; third-party MIT skills, hash-pinned, required by the mockup flow) and for `scripts/check-skills.sh`.
  - Quickstart bootstrap paragraph: add that vendored skill folders are copied whole and never replaced, that `skills-lock.json` is never overwritten, and that an existing skill folder means that skill's pin does not hold in the project.
  - Add a `## Vendored design skills` section after "Customizing" covering: update procedure (copy the new upstream folder over the old, run `bash scripts/check-skills.sh --hash .claude/skills/<name>`, put the digest in the lockfile in the same change); the em dash exemption and why (verbatim, hash-pinned; the no-em-dash hook still blocks new ones in edits); that vendored skills point to skills that are not vendored and those pointers are ignored; that verification runs in the template repository only; that `impeccable` is not vendored and is optional.
  - "Keeping the template honest": add the skills hash check and required-skills table check.

- [x] **Step 2: Edit `docs/codebase-map.md`.**
  - Replace the sentence "blocks finishing a turn while files were added, deleted, or renamed and this file was not touched" with "blocks finishing a turn while an added or renamed path has no row in this file, or a deleted path still has one".
  - Replace the Stop hook row's purpose with "Stop hook. Blocks finishing while an added or renamed file has no row here, or a deleted file keeps one."
  - Add the `docs/screenshots/` row to the docs table: "Before and after screenshots of front-end changes, one folder per feature."
  - Update the `scripts/check-template.sh` row to mention the skills hash check, and the Layout tree to include `skills-lock.json` and `THIRD_PARTY_LICENSES.md`.

- [x] **Step 3: Run `bash scripts/check-template.sh` and `bash tests/hooks.test.sh`.** Expected: both pass.

- [x] **Step 4: Stage** `git add README.md docs`.

### Task 6: Verify and fresh-context review

- [x] **Step 1: Full local run.** `bash scripts/check-template.sh`, `bash tests/hooks.test.sh`, `shellcheck -S warning scripts/*.sh`. Expected: all pass. Record any error hit in `docs/error-log.md` with the `log-error` skill.
- [x] **Step 2: Real flow.** Bootstrap into a scratch git repo at a path with a space, start from an empty directory, and confirm `.claude/skills/apple-design/SKILL.md`, `skills-lock.json` and `THIRD_PARTY_LICENSES.md` exist and `bash scripts/check-skills.sh <scratch>` passes.
- [ ] **Step 3: Stage everything** (`git add -A`) so the reviewer sees new files, then use the `fresh-review` skill against `origin/main`. Fix every finding that quotes a line, rerun Step 1, and re-review until "No objections found." or only defensible gaps remain.
- [ ] **Step 4: Report** to the owner what changed, the review outcome and known gaps. Ask whether to commit and open a PR. Do not merge.
