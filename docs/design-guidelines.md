# Design guidelines

Guardrails against the visual and copy patterns that read as generated rather
than designed. Every mockup gets checked against this list before it goes up
for approval (see **Mockup before build** in [`AGENTS.md`](../AGENTS.md)); a
mockup that breaks one of these goes back for another pass, not forward for a
yes. The same list applies at build time to anything a mockup did not cover (a
new state, an error message, a loading view). Never use any of these.

A few items below (pricing tiers, testimonials, a legal and privacy footer, a
product-screenshot hero) target public marketing pages. An internal tool may
have none of them today; keep them in mind the day a public-facing page gets
built.

## Color and light

1. No harsh gradients. No gradient hero backgrounds, gradient buttons, or big
   multi-hue sweeps. Use one flat brand color, or a real photograph.
2. No default icon-everywhere. Don't put the same starter icon set with
   identical strokes on every card. Use typographic glyphs (`+`, arrows,
   asterisks), numbers, or no icons at all.
3. No pure-white background. A white body with gray borders is the unstyled
   default. Use a tinted paper tone, or commit to a dark ground.
4. No rainbow coloring. One hue per feature card, five hues per page screams
   template. Use one accent color and neutrals tinted toward the brand hue.
5. No drop shadows on every card. One or two intentional shadows (a lifted
   object, a menu) are fine. Otherwise use thin 1px rules, flat surfaces,
   paper stacking.

## Layout

6. No "3 feature cards in a row." Heading, paragraph, three equal cards is the
   template rhythm. Use an asymmetric grid, a stacked list, one big plus two
   small, or editorial numbering.
7. No emojis as design elements. Not in headings, bullets, or feature icons.
   Use words, real icons, or designed glyphs.
8. No liquid glass. No blurred translucent cards floating over gradients. Use
   solid surfaces.
9. No em dashes. They are an LLM copy fingerprint. Use commas, colons, or full
   stops (a pipe is acceptable in titles). This is the same rule as "Never use
   em dashes" in `AGENTS.md`, restated here because it is also a visual-design
   tell, not just a style rule.
10. No default starter fonts. No Inter, Geist, Space Grotesk, or Roboto as the
    brand voice. Use a self-hosted typeface with character: one display face
    plus one text face.

## Components and copy

11. No colored left-stripe callouts. No thick colored border on the left side of
    cards and alerts. Use a top rule, an indent, or a background tint instead.
12. No fake testimonials. No quotes from stock personas with stock avatars.
    Remove them, or use one verifiable quote from a real person.
13. No bento grids. No Apple-style mixed-span tiles for features. Use linear
    sections.
14. No fake terminal windows. No `$ npm install` box on a non-developer
    product. Show a screenshot of the real product instead.
15. No "It's not X, it's Y" headlines. Also avoid "not just X, but Y." Just say
    what the thing is, plainly.
16. No checkmark bullets before every feature. Use a plain list, plus signs, en
    dashes, or numbering.

## Trust and conversion

17. No 3 pricing tiers. No Free / Pro / Enterprise in three equal cards with the
    middle one highlighted. Use one clear price, or a table.
18. Show the real product. A hero with a stock photo or an illustration, and
    never the product itself, reads as generated. Use one real screenshot, an
    embedded live sample, or a short video.
19. No uniform soft corner radius. Rounded-xl on everything is a giveaway. Use
    0–4px radius, or one deliberate large radius used sparingly.
20. No purple-on-black default. That is the AI-startup uniform. Use a committed
    brand hue with tinted neutrals.
21. Add skeleton loaders. Spinners and "Loading..." text that make the layout
    jump read as unfinished. Use skeletons shaped like the content.
22. No radial orbs. No blurred colored circles floating behind the hero. Remove
    them.
23. No dot grids. No radial-gradient dot background textures. Use a photograph
    or flat color.
24. No sparkle icons. No sparkles next to anything "AI." Remove them.
25. No animated arrows on every link. No arrow sliding right on hover on every
    link. Use a static arrow, or none.

## Honesty and motion

26. Include real legal links. A footer with no terms of service is a tell. Add
    terms and review what applies.
27. Include a privacy policy link. An imprint is not a privacy policy. Add one
    and review what applies.
28. No hover animations on every card. No scale-up, lift, or shadow on hover
    everywhere. One restrained lift on buttons is fine; otherwise change color
    or underline only.
29. No neon colors. No electric blue, lime, or cyan accents. Desaturate.
30. No default pastel fills. No light blue or light green tag and card fills. Go
    two-tone: ink and paper, or neutrals derived from the brand hue.

## Recording the project's own position

When the app already breaks a rule from before this list was adopted, add a
short section here naming the rule, the spot, and the decision (fix next time
that screen is touched, or accept). A visible change to shipped screens goes
through the mockup workflow like any other, not a drive-by palette swap.
