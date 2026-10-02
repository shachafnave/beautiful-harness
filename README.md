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
git clone <this-repo-url> beautiful-harness
beautiful-harness/scripts/bootstrap.sh /path/to/your/project
```

Bootstrap copies the harness into your project without overwriting anything that
already exists (add `--force` to overwrite), links `CLAUDE.md` to `AGENTS.md`,
adds the needed lines to `.gitignore`, and prints the `<<PLACEHOLDER>>` tokens
you still have to fill in. Then:

1. Fill in `AGENTS.md`: project name, the Commands table, shared layers, notes.
2. Fill in `docs/codebase-map.md` with your project's files.
3. Start a Claude Code session in the project. The session-start hook confirms
   the harness is live.

## What is in the box

| Piece | Where | What it does |
| --- | --- | --- |
| Working agreements | `AGENTS.md` (`CLAUDE.md` symlinks to it) | Six working methods (plan, subagents, self-improvement, verification, elegance, autonomous fixes) plus the code rules |
| Em dash guard | `.claude/hooks/no-em-dash.sh` | Blocks em dashes in written files, commit messages, and PR bodies |
| Branch guard | `.claude/hooks/protect-main.sh` | Blocks force pushes, pushes to the default branch, and commits on it |
| Definition of done | `.claude/hooks/definition-of-done.sh` | Blocks finishing a turn when files were added, deleted, or renamed and the codebase map was not updated |
| Session start | `.claude/hooks/session-start.sh` | Reminds the agent to search the error log and shows the newest entries |
| `/deploy` | `.claude/skills/deploy` | Verify, migration gate, fresh review, PR, squash-merge pinned to the head SHA, report, reset |
| `/mockup-round` | `.claude/skills/mockup-round` | Interview, mockup, guideline check, approval gate, plan, build |
| `/log-error` | `.claude/skills/log-error` | Search the log first, then record symptom, cause, fix, prevention |
| `/fresh-review` | `.claude/skills/fresh-review` | Dispatches the reviewer with the diff only |
| Reviewer agent | `.claude/agents/adversarial-reviewer.md` | Read-only; every objection must quote the exact line |
| Codebase map | `docs/codebase-map.md` | Every file and its purpose; part of the definition of done |
| Error log | `docs/error-log.md` | Every error hit, with its resolution and prevention |
| Design guidelines | `docs/design-guidelines.md` | Thirty rules against generated-looking UI and copy |
| MCP setup | `.mcp.json`, `docs/mcp.md` | Project-scope servers, with rules for secrets and approval |
| Settings | `.claude/settings.json` | Hook wiring, deny rules for `.env` files and force pushes, attribution off |
| PR template | `.github/pull_request_template.md` | Verification, review outcome, known gaps |

## How the hooks behave

Hooks receive the tool call as JSON on stdin. Exit code 2 blocks the action and
feeds stderr back to the agent; exit 0 allows it. Exit 1 means the hook itself
could not run (for example, `jq` is missing) and is shown without blocking.

- `no-em-dash.sh` runs before `Write`, `Edit`, `MultiEdit`, and `Bash`, so it
  also catches `git commit -m` and `gh pr create --body`.
- `protect-main.sh` treats `main` and `master` as protected. Override with
  `HARNESS_PROTECTED_BRANCHES="main develop"`. A first commit in an empty
  repository is allowed, and `git checkout -b x && git commit` in one command is
  allowed.
- `definition-of-done.sh` is silent when `docs/codebase-map.md` does not exist
  or the directory is not a git repository. Override the map path with
  `HARNESS_CODEBASE_MAP` and the ignored paths (a regex) with
  `HARNESS_MAP_IGNORE`.

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

## Keeping the template honest

`scripts/check-template.sh` validates the JSON files, the `CLAUDE.md` symlink,
skill and agent frontmatter, hook modes and wiring, the absence of em dashes and
of project-specific leftovers, the hook tests, and a bootstrap into a scratch
repository. CI runs it on every push and pull request.

## Conventions this repo follows itself

No em dashes, no comments in code, every file has a row in
`docs/codebase-map.md`, and no merge without a fresh-context review. Rationale
belongs in commit messages and docs, not in code comments.

## License

MIT. See [`LICENSE`](./LICENSE).
