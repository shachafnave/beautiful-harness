# Align the harness with the reference app's latest rules and design skills

Status: approved by the owner on 2026-11-20 and implemented on branch `feat/reference-alignment`.

## Intent and why

The harness started as one real product's working process and was generalized.
That product (the reference app) has kept moving: it picked up a vendored
design skill, stricter design guidelines, mechanical design guards, and several
small verification rules that came from real corrections. The owner wants the
harness to carry all of that as of today, and wants the design skills copied
into the harness so a new project gets them without installing anything.

The reference app is the freshest source of rules, but its rules file is older
than the harness's in several ways (three working methods, no hooks, no CI, no
agents). So this is not a copy of its rules file. It is a merge: keep everything
the harness already enforces, add what the reference app learned since, and add
the required-skills mechanism, which the reference app does not have.

## Goals

1. Five third-party design skills live inside the harness as real files:
   `apple-design`, `emil-design-eng`, `animate`, `review-animations`,
   `break-ui`. Bootstrap copies them into every new project.
2. The mockup flow names which of those skills must run, and when. Running them
   is a rule, not a hope that auto-triggering fires.
3. The vendored copies are pinned, so drift or a half-copied skill is caught by
   the template self-check.
4. The reference app's newer generic rules are written into `AGENTS.md`, the
   design guidelines, the skills and the PR template, in stack-neutral wording.
5. Known inaccuracies in the harness docs that the research surfaced are fixed
   in the same change.

## Non-goals

- Copying the reference app's product-specific material: its data model notes,
  portal tokens and Hebrew font rule, its daily-agent playbook, its registration
  loader skill, its migration numbering, its demo-mode command.
- Copying its mistakes: the unrelated `autoMode` block in its settings, its
  dangling legacy skill symlinks, and two contradictions inside its guidelines
  (no pure-white background versus white panels; a 0 to 4px radius versus 4 to
  10px).
- Vendoring `impeccable`. It is 19 MB, ships a browser toolchain, and works
  through user-level hooks. It is named in the mockup flow as "run it if
  installed".
- Adding the superpowers "required sub-skill" header to plans. The harness is
  stack and plugin neutral.
- Shipping a project-specific design-guard test file. The guidelines describe
  what such a test should check; each project writes its own.

## Anti-goals

- Anything in the template that names the reference app. The self-check's
  origin-project leak guard must keep passing, so this document and every change
  refer to it only as "the reference app".
- Weakening an enforced rule beyond the one stated exemption below.
- A fix that adds more machinery than it removes. Where a rule can live as one
  sentence in `AGENTS.md`, it does not become a hook.

## Constraints

- Template is stack neutral: bash, git and jq only. No new dependencies.
- Hooks and self-check must pass on macOS and on the Ubuntu CI runner.
- The harness follows its own rules: no em dashes, no comments in code, a row in
  `docs/codebase-map.md` for every file, fresh-context review before merge.
- The five skills are third-party and come from one public upstream GitHub
  repository, licensed MIT. Their folders contain no licence file, so the MIT
  notice is shipped alongside them and provenance and hash are recorded in the
  lockfile. The template repository is private today; projects bootstrapped
  from it may not be.
- The vendored files contain 193 em dashes between them (65, 13, 48, 50 and 17
  per skill). Editing them would break provenance and the hash.

## Approaches considered

| Approach | What it is | Trade-off |
| --- | --- | --- |
| A. Real copies in `.claude/skills/<name>/` (chosen) | Skills are plain files in the harness. A root `skills-lock.json` records source, path and a content hash. Bootstrap copies them like any other skill. | Simplest. No symlink handling anywhere. Other tools that read only an `.agents/` folder will not see them. |
| B. Real files in `.agents/skills/`, symlinks in `.claude/skills/` | The reference app's layout. | Visible to tools that read `.agents/`. Bootstrap and the self-check currently skip or reject symlinks, so both need new code. |
| C. Lockfile only, install on bootstrap | Bootstrap fetches skills from upstream. | Needs network and a tool at bootstrap time. Rejected by the owner: the skills are to be copied in. |

The owner chose A.

## Design

### 1. Vendored skills and lockfile

- Add `.claude/skills/<name>/` for each of the five skills, copied verbatim
  from the owner's installed copies (all five come from the same upstream
  repository). Include every file in each folder (`animate` and
  `review-animations` and `break-ui` carry a second reference file).
- Add `skills-lock.json` at the repo root. One entry per skill: `source`,
  `sourceType`, `sourceUrl`, `skillPath`, and `computedHash`. The hash is the
  sha256 of the folder's files in sorted relative-path order, each contributing
  its path, a newline and its bytes. The builder picks the exact shell
  implementation, which must give identical output with `sha256sum` and
  `shasum -a 256`.
- The self-check verifies, for every entry in the lockfile: the folder exists,
  `SKILL.md` frontmatter `name` equals the folder name, and the recomputed hash
  equals the recorded one. It also fails if a skill named in the mockup flow's
  required-skills table has no lockfile entry.
- Em dash exemption: the em dash scan skips the folders listed in
  `skills-lock.json`. The no-em-dash hook is unchanged, so editing a vendored
  file through Write or Edit is still blocked if it introduces one. `AGENTS.md`
  states the exemption in the em dash rule: vendored third-party skills are kept
  verbatim and hash-pinned.
- To update a skill: copy the new upstream folder over it and update the hash in
  the same change. Document this in `README.md`.
- Bootstrap copies the five folders and `skills-lock.json`. It never overwrites
  an existing `skills-lock.json` in the target, even with `--force`, and prints
  a note to merge entries by hand, the same way it treats `settings.json`.

### 2. Required skills in the mockup flow

`AGENTS.md` (mockup section) and the `mockup-round` skill gain a short table:

| When | Skill | Required |
| --- | --- | --- |
| Mockup step | `apple-design`, `emil-design-eng` | Yes |
| Mockup step | `impeccable` | If installed |
| Mockup shows motion (transitions, sheets, press, gestures) | `animate` | Yes |
| Before presenting the mockup | `break-ui` (worst-case data pass) | Yes |
| After build, when the change includes motion | `review-animations` | Yes |

A mockup is not presented until the required rows have run. The PR template
gains a checkbox for it.

### 3. Rules carried over from the reference app

Written generically, in `AGENTS.md` Code rules unless noted:

- UI verification: check non-trivial UI changes in a seeded or demo instance, not
  against live data. The Commands table gains a `Demo instance` row with a
  `<<DEMO_COMMAND>>` placeholder. Screenshots are committed under
  `docs/screenshots/<feature>/` as `before-*.png` and `after-*.png`.
- After rebasing a long-lived branch, rerun the full test suite, not only build
  and lint.
- Schema changes: add a new migration, never edit one already applied. Apply it
  to the live system before merging code that reads the new shape. (The `deploy`
  skill already stops at a migration gate; this states the principle.)
- Live data: confirm with the user before the first write to a live system, and
  read untrusted input files with an isolated interpreter in their own folder.
- Mechanical design guards: where a design rule can be checked by scanning
  source (no raw colour values outside tokens, no gradients, press state on every
  action class), write it as a test. Stated in the design guidelines.

### 4. Design guidelines

- Rule 2 is tightened: icons appear only on action buttons, from one set, beside
  the label and in the button's own text colour. None on cards, headings,
  feature blocks or empty states.
- New rule: every action control has a press state (a short scale or tint
  change on `:active`), switched off under reduced motion.
- Rule 10 gains: text sizes come from one scale in `rem`, with tighter tracking as
  size grows. The no-starter-fonts wording stays.
- The closing section on recording a project's own position stays, and now also
  points to the mechanical guard tests.
- Rule count changes from thirty to thirty-one wherever it is stated.

### 5. Corrections to existing harness docs

- `docs/codebase-map.md` says the Stop hook blocks when "this file was not
  touched". The hook checks for a backticked row per added, renamed or deleted
  path. Fix the sentence.
- `README.md`: list the new skills and lockfile in "What is in the box", describe
  the hash check and the em dash exemption, and add the update procedure.
- Add rows to `docs/codebase-map.md` for every new file and folder
  (`.claude/skills/<name>/`, `skills-lock.json`, `docs/superpowers/specs/`,
  `docs/screenshots/` when it exists), plus a "Last regenerated" date.

### 6. Verification

- `tests/hooks.test.sh` is unaffected (hooks do not change).
- `scripts/check-template.sh` gains the lockfile checks and the exemption. Its
  bootstrap integration tests gain: skills and lockfile copied into a fresh
  target; an existing target `skills-lock.json` is preserved with `--force`; a
  tampered vendored file makes the check fail; a required skill missing from the
  lockfile makes it fail.
- Run `bash scripts/check-template.sh` locally and in CI.
- A fresh-context reviewer attacks the diff before merge.

## Settled during review

A fresh reader of this design raised six questions. None needs the owner; each
is settled here and marked as a call.

1. **Skills versus guidelines.** `apple-design` recommends translucent
   `backdrop-filter` layers, blur and gradient scroll masks, and
   blur-plus-scale entrances. Guideline rules 1 and 8 ban gradients and
   blurred translucent surfaces. The guidelines win. The skills supply craft
   (typography, motion, press and gesture feel, interruptibility); they do not
   override the material rules. The reference app made the same call: its
   approved redesign used the skill and kept solid surfaces. The sentence goes
   in the guidelines intro, in `AGENTS.md` beside the required-skills table, and
   in `mockup-round`. No guideline gets a carve-out.
2. **Licence.** The upstream licence is MIT. Ship its notice in
   `THIRD_PARTY_LICENSES.md` at the repo root and record `license: MIT` in each
   lockfile entry. Bootstrap copies the notice with the skills.
3. **Dangling references and bare invocation.** The vendored skills mention
   skills that are not vendored (`gestures`, `choreograph`,
   `animation-performance`, `animate-expo`, `improve-animations`,
   `find-animation-opportunities`). Leave the references; the files stay
   verbatim. The README says so, and `mockup-round` says to ignore a pointer to
   a skill that is not installed. Each of the skills opens with a canned
   greeting when invoked without a task, so `mockup-round` says to invoke each
   with the specific screen and question, never bare.
4. **Where the pin holds.** The hash check runs in the template repository's
   self-check. Bootstrap does not copy the check. If a target already has a
   folder with a vendored skill's name, bootstrap skips the whole folder and
   prints a warning that the pin does not hold there. Bootstrap never mixes
   files into an existing skill folder. The README states that verification is
   template-side.
5. **Screenshots.** Committed under `docs/screenshots/<feature>/`, as in the
   reference app. The PR template checkbox links the folder. The map carries one
   row for `docs/screenshots/`. This replaces "attached to the PR" in the
   current rule, template and `deploy` skill.
6. **Demo instance.** The rule requires a seeded or demo instance and never live
   data. `<<DEMO_COMMAND>>` is the command that starts it. A project with none
   writes `n/a` and the reason in the Commands table and uses its local dev
   instance with seed data; it is not forced to build a demo mode.

New guideline rules go at the end (number 31) to avoid renumbering. The
required-skills table lives in `AGENTS.md`, and `mockup-round` points to it.

## Calls I made (check these)

- Guidelines override the vendored skills where they conflict.
- Whole-folder skip when a vendored skill's folder already exists in a target.
- Screenshots are committed, not attached.
- `n/a` is an allowed value for the demo instance command.
- Proceeding with MIT-licensed upstream, notice shipped in
  `THIRD_PARTY_LICENSES.md`.
- The skill set, and which step each belongs to.
- Leaving `impeccable` out of the vendored set (size, hook-based).
- Exempting vendored folders from the em dash scan rather than editing them.
- Not adopting the reference app's daily-agent playbook, registration loader
  skill, or plan header.
- A `<<DEMO_COMMAND>>` placeholder in the Commands table.
- Making press state a new guideline rule instead of folding it into an existing
  one.
- Making the lockfile merge-only on bootstrap.

## Left to the builder

- Exact hash implementation and lockfile field order.
- Wording of each new rule, within the meaning above.
- Whether the self-check reads the required-skills table from `AGENTS.md` or
  from the `mockup-round` skill, provided one place is the source of truth and
  the other points to it.
- Fetching the exact MIT notice text and copyright line from the upstream
  repository for `THIRD_PARTY_LICENSES.md`.
