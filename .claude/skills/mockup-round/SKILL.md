---
name: mockup-round
description: "Run the mockup-before-build flow for any new or changed UI surface: interview, HTML mockup, guideline check, approval gate, plan, build. Use before writing code for a new screen, component, or visible redesign."
---

# Mockup round

Skip this skill for pure bug fixes, refactors, and backend-only work. Everything
else that changes what a person sees goes through these steps in order. Do not
start a step until the previous one is done.

## 1. Interview

Ask the questions whose answers would change the design, before drawing
anything: who uses the screen, what they do on it, which states exist (empty,
loading, error, populated), what data it shows, what differs by role, and what
it must match in the existing app. Do not guess at intent. Stop asking when the
remaining questions would not change the design.

## 2. Mockup

Pick a round name and save the work as `mockups/<round-name>/<screen>.html`.

- Self-contained: inline CSS, no build step, opens by double-clicking.
- Realistic data from the project's seed or fixtures, never lorem ipsum.
- The app's real design tokens, read from its stylesheet, not invented ones.
- One file per screen; show each role's view when a surface differs by role.
- Run the required design skills from `AGENTS.md` (Required design skills)
  before drawing, each invoked with the specific screen and question, never
  bare. Where a skill and the guidelines disagree, the guidelines win. Ignore a
  pointer to a skill that is not installed.

Add a row for each new file to `docs/codebase-map.md` and a row for the round to
the table in `mockups/README.md` (delete the `_none yet_` placeholder row when
adding the first one), in the same change.

## 3. Guideline check

Before presenting, read `docs/design-guidelines.md` and check the mockup against
every rule, one by one. Fix violations first. A mockup that breaks a guideline
goes back for another pass, not forward for approval. State in your message
that the check was done and which rules needed fixing. Run `break-ui` on the
mockup before presenting it, and say which required skills ran.

## 4. Approval

The mockup is the gate. Show it (screenshot or open it) and wait for an explicit
yes. Iterate on the mockup, not in code. Set the round's status in
`mockups/README.md` to `Awaiting approval`, then `Approved` once the user says
yes.

## 5. Plan

Once approved, write the implementation plan: files touched, shared helpers
needed, data or schema changes, and how the result will be verified.

## 6. Build

Implement against the approved mockup. Verify in the demo instance (the Demo
instance row in `AGENTS.md`), click through the flow that changed, and commit
before and after screenshots taken with realistic data under
`docs/screenshots/<feature>/` as `before-*.png` and `after-*.png`. If the change
includes motion, ask the user to run `/review-animations` (the model cannot
invoke that skill) and wait for the result. Update the round's status to
`Approved, built`.

## Red flags

| Thought | Reality |
| --- | --- |
| "I know what they want, skip the interview." | Guessing intent is how mockups get thrown away. Ask first. |
| "It's a small UI tweak, I'll just build it." | A visible change is a UI surface. Mock it, or confirm the user waived the mockup. |
| "They said it looks good, that's approval." | Approval is an explicit yes to this mockup. Ask if unsure. |
| "I'll fix the remaining issues in code." | Iterate on the mockup, not in code. |
| "The skill says to use blur, so I will." | The guidelines win where they disagree with a skill. Use solid surfaces. |
