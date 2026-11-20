# beautiful-harness

A reusable Claude Code harness: the working agreements, skills, agent, hooks,
and doc scaffolds that make an AI-assisted project predictable. It started as
the process of one real product and was generalized to be stack-neutral.

The idea: rules written in prose get forgotten, so the ones that can be checked
by a machine are enforced by hooks, and the ones that need judgment live in
skills and an adversarial reviewer.

## Quickstart

Requires `bash`, `git`, and [`jq`](https://jqlang.github.io/jq/) (the hooks use
it).

```bash
git clone https://github.com/shachafnave/beautiful-harness.git
beautiful-harness/scripts/bootstrap.sh /path/to/your/project
```

Bootstrap copies the harness into your project without overwriting anything that
already exists, links `CLAUDE.md` to `AGENTS.md`, adds the needed lines to
`.gitignore`, and prints the `<<PLACEHOLDER>>` tokens you still have to fill in.
`--force` overwrites other existing files but never `.claude/settings.json` or
`.mcp.json`, and never writes through symlinks. If your project already has a
`.claude/settings.json`, the hooks are copied but not active until you merge the
`permissions` and `hooks` blocks by hand; bootstrap says so. If you already have
a real `CLAUDE.md`, it is left alone. Vendored skill folders are copied whole and
never replaced, and an existing `skills-lock.json` or `THIRD_PARTY_LICENSES.md`
is never overwritten (merge them by hand); if a
skill folder already exists in your project, that skill's pin does not hold
there. Then:

1. Fill in `AGENTS.md`: project name, the Commands table, shared layers, notes.
2. Fill in `docs/codebase-map.md` with your project's files.
3. Start a Claude Code session in the project. The session-start hook prints
   the working methods, which confirms the harness is live.

## What is in the box

| Piece | Where | What it does |
| --- | --- | --- |
| Working agreements | `AGENTS.md` (`CLAUDE.md` symlinks to it) | Six working methods (plan, subagents, self-improvement, verification, elegance, autonomous fixes) plus the code rules |
| Em dash guard | `.claude/hooks/no-em-dash.sh` | Blocks em dashes in written files, commit messages, and PR bodies |
| Branch guard | `.claude/hooks/protect-main.sh` | Blocks force pushes, pushes to protected branches, and commits, cherry-picks, reverts, and non-fast-forward merges on them |
| Definition of done | `.claude/hooks/definition-of-done.sh` | Blocks finishing a turn when uncommitted added or renamed files have no row in the codebase map, or deleted files keep one |
| Session start | `.claude/hooks/session-start.sh` | Prints the working methods and red flags from `AGENTS.md`, then the newest error log entries. Runs on startup, resume, clear, and compact, so the rules survive long sessions |
| `/deploy` | `.claude/skills/deploy` | Verify, migration gate, fresh review, PR, squash-merge pinned to the head SHA, report, reset |
| `/mockup-round` | `.claude/skills/mockup-round` | Interview, mockup, guideline check, approval gate, plan, build |
| `/log-error` | `.claude/skills/log-error` | Search the log first, then record symptom, cause, fix, prevention |
| `/fresh-review` | `.claude/skills/fresh-review` | Dispatches the reviewer with the diff only |
| Reviewer agent | `.claude/agents/adversarial-reviewer.md` | Read-only; every objection must quote the exact line |
| Codebase map | `docs/codebase-map.md` | Every file and its purpose; part of the definition of done |
| Error log | `docs/error-log.md` | Every error hit, with its resolution and prevention |
| Design guidelines | `docs/design-guidelines.md` | Thirty-one rules against generated-looking UI and copy |
| Design skills | `.claude/skills/{animate,apple-design,break-ui,emil-design-eng,review-animations}`, `skills-lock.json`, `THIRD_PARTY_LICENSES.md` | Third-party MIT skills copied in and pinned by hash; the mockup flow requires them |
| Skills check | `scripts/check-skills.sh` | Verifies the lockfile and the required-skills table; `--hash <dir>` prints a folder hash |
| MCP setup | `.mcp.json`, `docs/mcp.md` | Project-scope servers, with rules for secrets and approval |
| Settings | `.claude/settings.json` | Hook wiring, a small read-only allow list, deny rules for `.env` reads and force pushes, attribution off |
| PR template | `.github/pull_request_template.md` | Verification, review outcome, known gaps |

## How the hooks behave

Hooks receive the tool call as JSON on stdin. Exit code 2 blocks the action and
feeds stderr back to the agent; exit 0 allows it; exit 1 is a hook failure that
is shown without blocking. Without `jq`, `protect-main.sh` and `no-em-dash.sh`
block when the input looks relevant (a git command, an em dash) and otherwise
stay out of the way, so you can still install `jq`.

- `no-em-dash.sh` runs before `Write`, `Edit`, `MultiEdit`, `NotebookEdit`, and
  `Bash`. For `Bash` it only inspects commands that write prose (`git commit`,
  `git tag`, `gh pr`, `gh issue`, `gh release`), so searching for the character
  is allowed.
- `protect-main.sh` treats `main` and `master` as protected. Override with
  `HARNESS_PROTECTED_BRANCHES="main develop"`. It blocks force pushes (including
  `-fu` and `+refspec`), `--all`, `--mirror`, any push naming a protected branch,
  a push from a protected branch that names no other branch, and history-changing
  commands on a protected branch. A first commit in an empty repository is
  allowed, `git checkout -b x && git commit` in one command is allowed, and
  `git pull` and `git merge --ff-only` are allowed.
- `definition-of-done.sh` compares the working tree to `docs/codebase-map.md`:
  every added, renamed, or untracked path needs its path in backticks in the map
  (or a backticked parent directory such as `` `src/` ``), and a deleted path
  must not keep its row. It is silent when the map does not exist or the
  directory is not a git repository. Override the map path with
  `HARNESS_CODEBASE_MAP` and the ignored paths (a regex) with
  `HARNESS_MAP_IGNORE`. A per-session cap (`HARNESS_MAX_BLOCKS`, default 3)
  stops it from looping if the agent cannot satisfy it.

Known limits. These hooks are guardrails against honest mistakes, not a security
boundary: a command can build a string at runtime (`git push origin $BRANCH`),
a shell redirect can write a file without the `Write` tool, and the Stop hook
only sees uncommitted changes, so files that were committed without a map row
pass. The `Read(**/.env)` deny rules cover the Read tool, not `cat .env`.
The reviewer agent is read-only by instruction, not by enforcement.

Run the hook tests any time:

```bash
bash tests/hooks.test.sh
```

## Customizing

- **Add a rule.** Put it in `AGENTS.md`. If a machine can check it, add a hook
  and a case in `tests/hooks.test.sh`.
- **Add a skill.** Create `.claude/skills/<name>/SKILL.md` with `name` matching
  the folder and a `description` that says when to use it. Add its row to
  `docs/codebase-map.md`.
- **Add an MCP server.** See `docs/mcp.md`.
- **Change the design rules.** Edit `docs/design-guidelines.md` and record any
  deliberate exceptions in its last section.

## Vendored design skills

Five third-party skills (`apple-design`, `emil-design-eng`, `animate`,
`review-animations`, `break-ui`, from `emilkowalski/skills`, MIT) live in
`.claude/skills/` as real files and are pinned in `skills-lock.json`. The
mockup flow requires them (see **Required design skills** in `AGENTS.md`).
`impeccable` is optional and not vendored.

- **Verbatim.** The files are never edited. They contain em dashes, so the
  self-check skips the folders listed in the lockfile; the no-em-dash hook still
  blocks new ones in edits.
- **Updating a skill.** Copy the new upstream folder over the old one, run
  `bash scripts/check-skills.sh --hash .claude/skills/<name>`, and put the
  digest in `skills-lock.json` in the same change.
- **Dangling pointers.** The skills mention skills that are not vendored
  (`gestures`, `choreograph`, and others). Ignore those pointers.
- **Where the pin holds.** `scripts/check-skills.sh` runs in this repository's
  self-check and is not copied by bootstrap. Bootstrap copies skill folders
  whole, skips any folder that already exists, and says so.

## Keeping the template honest

`scripts/check-template.sh` validates the JSON files, the `CLAUDE.md` symlink,
skill and agent frontmatter, hook modes and wiring, the vendored skill hashes and
the required-skills table, the absence of em dashes and of project-specific
leftovers, the hook tests, and a bootstrap into a scratch repository. CI runs it
on every push and pull request.

## Conventions this repo follows itself

No em dashes, no comments in code, every file has a row in
`docs/codebase-map.md`, and no merge without a fresh-context review. Rationale
belongs in commit messages and docs, not in code comments.

## License

MIT. See [`LICENSE`](./LICENSE).
