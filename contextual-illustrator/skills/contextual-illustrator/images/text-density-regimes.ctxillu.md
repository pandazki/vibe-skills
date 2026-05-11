---
image: text-density-regimes.png
generated_at: 2026-04-30T00:00:00Z
model: gpt-image-2
backend: fal
aspect_ratio: 16:9
quality: high
text_density: dense
---

# Spec: text-density-regimes.png

## Context
Sibling explainer for the same `contextual-illustrator` skill. Visualizes the Step 4 guidance about matching text density to image purpose — the principle most likely to be misapplied if relying on prose alone. Pairs with `workflow-overview.png` as part of the skill's documentation set.

## Subject
Side-by-side two-card composition contrasting the two density regimes: an information-carrying card showing a mock SaaS dashboard fragment with full text, vs an atmospheric card showing a soft landscape with no rendered text. The image is itself an example of both regimes coexisting on one canvas.

## Style
Adopted verbatim from `workflow-overview.ctxillu.md`. Flat technical-illustration. Warm cream/off-white background (`#FAF6F0`), deep navy strokes and primary text (`#1F2A44`), accents in sage green (`#7A9E7E`) and dusty coral (`#C97B6E`). Generous whitespace, no drop shadows, subtle dotted-grid backdrop. Sans-serif (Inter / Söhne register). Technical but warm — never corporate-cold blue-on-white.

The color assignment carries semantic weight in this set: **sage green = information / "good" density when text is needed; dusty coral = atmospheric / "good" sparseness when text isn't.** Reuse this association in any future "principle" diagrams.

## Composition
16:9 landscape. Title and subtitle stacked at the top. Two equal-width rounded-rectangle cards filling the lower 75% of the canvas with a small gap between them. Each card has a colored header tag pill at top, a body region (mock UI on left, landscape on right), and an italic caption underneath.

## Text & Typography
Density: **dense on the left card; deliberately empty in the right card body** (the contrast is the message). All text in the left card is rendered exactly as specified — no paraphrase or substitution.

Rendered strings:
- Title: `Match text density to purpose`
- Subtitle: `two regimes — pick the one the image is for`
- Left header tag: `Information-carrying` (white text on sage pill)
- Left dashboard header: `Sales Pipeline — Q4 2025`
- Left KPI tiles: `Pipeline / $4.2M`, `Closed Won / $1.8M`, `Win Rate / 38%`
- Left nav row: `Overview · Deals · Contacts · Reports · Settings`
- Left caption (italic): `list every label · pursue accuracy`
- Right header tag: `Atmospheric` (white text on dusty coral pill)
- Right caption (italic): `no rendered text · let the page speak`

## User Preferences
Inherited from `workflow-overview.ctxillu.md`:
- Information-carrying images: list every label in full; never paraphrase or substitute "etc."
- Aesthetic register: technical but warm.
- Sibling diagrams should preserve some equivalent loop / memory motif from the hero. (Attempted here via a small navy circular arrow between the two cards — the model elided that detail; not worth a regen.)

## Prompt
> A horizontal two-card composition for a technical-skill documentation series, in the same flat illustration style as the sibling 'contextual-illustrator workflow' diagram. Reuse this established palette and treatment exactly: warm cream/off-white background (#FAF6F0), deep navy strokes and primary text (#1F2A44), accents in sage green (#7A9E7E) and dusty coral (#C97B6E). Generous whitespace, no drop shadows, subtle dotted-grid backdrop. Sans-serif typography throughout (Inter or Söhne register). Technical but warm — explicitly avoid corporate-cold blue-on-white.
>
> Title at top, large and bold: 'Match text density to purpose'
> Subtitle below in lighter weight: 'two regimes — pick the one the image is for'
>
> Two rounded-rectangle cards side by side in the lower 75% of the canvas, equal width, with a small gap between them.
>
> LEFT CARD — header tag pill at the top in sage green (#7A9E7E) with white text reading 'Information-carrying'. The card body is a mock SaaS dashboard fragment showing dense, accurate text rendered legibly:
> - Dashboard header in bold: 'Sales Pipeline — Q4 2025'
> - A single row of three KPI tiles, each a small bordered rectangle with a label on top and a bold value below:
>   - Tile 1: label 'Pipeline', value '$4.2M'
>   - Tile 2: label 'Closed Won', value '$1.8M'
>   - Tile 3: label 'Win Rate', value '38%'
> - Below the tiles, a horizontal nav row in lighter weight: 'Overview · Deals · Contacts · Reports · Settings'
> Below the dashboard mock, an italic caption: 'list every label · pursue accuracy'
>
> RIGHT CARD — header tag pill at the top in dusty coral (#C97B6E) with white text reading 'Atmospheric'. The card body is a soft minimal landscape — three gentle rolling hills in muted sage tones, a single warm dusty-coral disc low on the horizon as a soft sun, generous empty cream space above. NO overlay text inside the landscape area whatsoever — the whole point of this card is to show that some images intentionally carry no rendered text.
> Below the landscape, an italic caption: 'no rendered text · let the page speak'
>
> A short navy thin dashed vertical separator runs between the two cards, and a small navy circular arrow icon sits at the top of the separator — a quiet visual rhyme to the loop motif of the workflow hero diagram.
>
> 16:9 landscape. All text in the LEFT card rendered legibly and exactly as specified; the RIGHT card is intentionally text-free in its body apart from its header tag and the italic caption underneath.

## Iteration Notes
- 2026-04-30 — initial generation. Style adopted from `workflow-overview.ctxillu.md`. Model dropped two requested details (the inter-card dashed separator and the small navy circular arrow icon between cards); main message lands clearly without them, no regen.
