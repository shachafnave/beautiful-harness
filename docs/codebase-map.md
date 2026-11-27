# Codebase map

Every file in the repo, what it is for, and what it depends on. **This file is
part of the definition of done: no new file lands without its row here, and no
file is deleted or renamed without its row being updated in the same change.**

The `definition-of-done` Stop hook blocks finishing a turn while an added or
renamed path has no row in this file, or a deleted path still has one.

Last regenerated: <<DATE>>.

## Layout

```
<<PROJECT_NAME>>/
├── AGENTS.md              working agreements (CLAUDE.md is a symlink to it)
├── CLAUDE.md              symlink to AGENTS.md
├── .mcp.json              project-scope MCP servers
├── skills-lock.json       records the vendored third-party skills and hashes
├── THIRD_PARTY_LICENSES.md  MIT notice for the vendored skills
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
| `skills-lock.json` | Records each vendored third-party skill's source, license, and sha256 of its folder. The template repository verifies it; the check script is not copied into projects. |
| `THIRD_PARTY_LICENSES.md` | MIT notice for the vendored skills. |

## .claude/

| File | Purpose |
| --- | --- |
| `.claude/settings.json` | Shared Claude Code settings: permissions, hook wiring, attribution. |
| `.claude/hooks/no-em-dash.sh` | PreToolUse hook. Blocks em dashes in written files, commit messages, and PR bodies. |
| `.claude/hooks/protect-main.sh` | PreToolUse hook. Blocks force pushes, direct pushes to the default branch, and commits on it. |
| `.claude/hooks/definition-of-done.sh` | Stop hook. Blocks finishing while an added or renamed file has no row here, or a deleted file keeps one. |
| `.claude/hooks/session-start.sh` | SessionStart hook. Prints the working methods and red flags from `AGENTS.md`, then the newest error log entries. Runs on startup, resume, clear, and compact. |
| `.claude/skills/deploy/SKILL.md` | `/deploy`: verify, migration gate, fresh review, PR, squash-merge, report, reset the branch. |
| `.claude/skills/mockup-round/SKILL.md` | Interview, mockup, guideline check, approval gate, plan, build for UI work. |
| `.claude/skills/log-error/SKILL.md` | Search the error log, then add an entry in the fixed format. |
| `.claude/skills/fresh-review/SKILL.md` | Dispatch the adversarial reviewer on a diff with no author context. |
| `.claude/skills/apple-design/` | Vendored third-party skill: Apple-style typography, motion, and interaction principles. Required in the mockup step. |
| `.claude/skills/emil-design-eng/` | Vendored third-party skill: interaction polish and the details that make components feel right. Required in the mockup step. |
| `.claude/skills/animate/` | Vendored third-party skill: building an animation from the decision to animate through the curve. Required when a mockup shows motion. |
| `.claude/skills/review-animations/` | Vendored third-party skill: reviewing existing motion against standards. Required after a build that includes motion. |
| `.claude/skills/brag-slim/` | Vendored third-party skill (`latent-spaces/brag`): turns a project or website into a short launch video. Optional, not part of the mockup flow. |
| `.claude/skills/break-ui/` | Vendored third-party skill: worst-case data pass over a piece of UI. Required before a mockup is presented. |
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
| `docs/design-guidelines.md` | Thirty-one rules against generated-looking visual and copy patterns. Mockups are checked against it. |
| `docs/mcp.md` | How MCP servers are wired into the project and how to add one safely. |
| `docs/screenshots/` | Before and after screenshots of front-end changes, one folder per feature. Created by the first UI change. |

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
| `.gitignore` | Ignored paths, including `brag-output/` from the optional `brag-slim` skill. |
| `.github/workflows/check.yml` | CI: runs the template self-check and the hook tests. |
| `scripts/bootstrap.sh` | Copies the harness into a target project without overwriting existing files. |
| `scripts/check-skills.sh` | Verifies each `skills-lock.json` entry (folder, frontmatter name, license, sha256). `--hash <dir>` prints a folder hash for updating the lockfile. |
| `scripts/check-template.sh` | Self-check: JSON validity, symlink, skill and agent frontmatter, hook modes, vendored skill hashes and the required-skills table, forbidden characters, leftover project names. |
| `tests/hooks.test.sh` | Feeds fixture JSON to every hook and asserts the exit codes. |
| `docs/superpowers/specs/` | Written designs for planned work on the template, dated. Approved before the plan is written. |
| `docs/superpowers/plans/` | Implementation plans for that work, dated. |
| `docs/assets/hero.svg` | Hero graphic shown at the top of `README.md`. |
