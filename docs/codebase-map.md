# Codebase map

Every file in the repo, what it is for, and what it depends on. **This file is
part of the definition of done: no new file lands without its row here, and no
file is deleted or renamed without its row being updated in the same change.**

The `definition-of-done` Stop hook blocks finishing a turn while files were
added, deleted, or renamed and this file was not touched.

Last regenerated: <<DATE>>.

## Layout

```
<<PROJECT_NAME>>/
├── AGENTS.md              working agreements (CLAUDE.md is a symlink to it)
├── CLAUDE.md              symlink to AGENTS.md
├── .mcp.json              project-scope MCP servers
├── .claude/               settings, hooks, skills, agents
├── .github/               pull request template
├── docs/                  this map, the error log, design guidelines, MCP notes
└── mockups/               approved HTML mockups, one folder per design round
```

## Root

| File | Purpose |
| --- | --- |
| `AGENTS.md` | Working agreements for every agent and tool. `CLAUDE.md` symlinks to it. |
| `CLAUDE.md` | Symlink to `AGENTS.md`. |
| `.mcp.json` | Project-scope MCP server definitions. Empty until a server is added; see `docs/mcp.md`. |

## .claude/

| File | Purpose |
| --- | --- |
| `.claude/settings.json` | Shared Claude Code settings: permissions, hook wiring, attribution. |
| `.claude/hooks/no-em-dash.sh` | PreToolUse hook. Blocks em dashes in written files, commit messages, and PR bodies. |
| `.claude/hooks/protect-main.sh` | PreToolUse hook. Blocks force pushes, direct pushes to the default branch, and commits on it. |
| `.claude/hooks/definition-of-done.sh` | Stop hook. Blocks finishing while files were added, deleted, or renamed without a change to this map. |
| `.claude/hooks/session-start.sh` | SessionStart hook. Reminds the agent to search the error log and shows the newest entries. |
| `.claude/skills/deploy/SKILL.md` | `/deploy`: verify, migration gate, fresh review, PR, squash-merge, report, reset the branch. |
| `.claude/skills/mockup-round/SKILL.md` | Interview, mockup, guideline check, approval gate, plan, build for UI work. |
| `.claude/skills/log-error/SKILL.md` | Search the error log, then add an entry in the fixed format. |
| `.claude/skills/fresh-review/SKILL.md` | Dispatch the adversarial reviewer on a diff with no author context. |
| `.claude/agents/adversarial-reviewer.md` | Read-only reviewer agent. Every objection quotes the exact line. |

## .github/

| File | Purpose |
| --- | --- |
| `.github/pull_request_template.md` | PR body: change, verification, review outcome, known gaps. |

## docs/

| File | Purpose |
| --- | --- |
| `docs/codebase-map.md` | This file. |
| `docs/error-log.md` | Every error hit, with cause, resolution, and prevention. Search it first. |
| `docs/design-guidelines.md` | Thirty rules against generated-looking visual and copy patterns. Mockups are checked against it. |
| `docs/mcp.md` | How MCP servers are wired into the project and how to add one safely. |

## mockups/

| File | Purpose |
| --- | --- |
| `mockups/README.md` | Mockup conventions and the table of design rounds. |

## Template repo only

These rows describe files that exist in the template repository and are not
copied into a project by `scripts/bootstrap.sh`.

| File | Purpose |
| --- | --- |
| `README.md` | What the template is, how to adopt it, what each piece does. |
| `LICENSE` | MIT license. |
| `.gitignore` | Ignored paths. |
| `.github/workflows/check.yml` | CI: runs the template self-check and the hook tests. |
| `scripts/bootstrap.sh` | Copies the harness into a target project without overwriting existing files. |
| `scripts/check-template.sh` | Self-check: JSON validity, symlink, skill and agent frontmatter, hook modes, forbidden characters, leftover project names. |
| `tests/hooks.test.sh` | Feeds fixture JSON to every hook and asserts the exit codes. |
