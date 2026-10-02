# mockups/

Approved HTML mockups. Every new or changed UI surface passes through here
before any application code is written. See **Mockup before build** in
[`AGENTS.md`](../AGENTS.md) for the full flow (interview, mockup, approval,
plan, build), or run the `mockup-round` skill.

## Conventions

- One folder per design round: `mockups/<round-name>/<screen>.html`.
- Each file is self-contained: inline CSS, no build step, opens by
  double-clicking. No external dependencies beyond a web font.
- Realistic data, never lorem ipsum. Pull names and numbers from the project's
  seed or fixture data so the mockup and the running app agree.
- Match the app's real design tokens. A mockup in a different visual language
  does not test the thing being approved.
- Check every mockup against [`docs/design-guidelines.md`](../docs/design-guidelines.md)
  before presenting it. A mockup that breaks a rule goes back for another pass.
- Show every role's view when a surface differs by role.
- Mockups are kept after they ship. They are the record of what was approved.

## Rounds

| Round | Covers | Status |
| --- | --- | --- |
| _none yet_ | | |
