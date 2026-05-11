---
image: workflow-overview.png
generated_at: 2026-04-30T00:00:00Z
model: gpt-image-2
backend: fal
aspect_ratio: 16:9
quality: high
text_density: dense
---

# Spec: workflow-overview.png

## Context
README hero for the `contextual-illustrator` skill itself (self-bootstrap). Sits at the top of `README.md` to give a one-glance explanation of how the skill works and what makes it different from a bare image-API call (the cross-session style memory loop via sidecars).

## Subject
Five-stage horizontal workflow diagram of the skill — Scan → Analyze → Craft → Generate → Capture — with a curved feedback arrow looping from Capture back to Scan. The loopback is the visual centerpiece: it's the story of "this session's spec becomes next session's input."

## Style
Flat technical-illustration. Warm cream/off-white background (`#FAF6F0`), deep navy strokes and primary text (`#1F2A44`), restrained accents in sage green (`#7A9E7E`) for the feedback loop and dusty coral (`#C97B6E`) for the numbered step circles. Generous whitespace, no drop shadows, subtle dotted-grid backdrop for technical feel without visual noise. Sans-serif throughout (Inter / Söhne register). Reuse this palette and treatment verbatim for any sibling diagrams in this skill.

## Composition
16:9 landscape. Title and subtitle stacked at the top. Five rounded-rectangle cards arranged left-to-right in the upper ~60% of the canvas, connected by thin straight right-pointing arrows. The lower ~30% holds a single sage-green curved arrow looping from the bottom-right of the last card back to the top-left of the first, with its label centered along the curve.

## Text & Typography
Density: **dense** (information-carrying — every stage has a title plus a multi-line subtitle, all legible). All strings rendered exactly as written, no paraphrase:

- Title: `contextual-illustrator workflow`
- Subtitle: `context-aware images with cross-session style memory`
- Card 1 — `1` · `Scan` · `Find .ctxillu.md sidecars / Read nearby images`
- Card 2 — `2` · `Analyze` · `Surrounding content / Tone / Purpose / Placement`
- Card 3 — `3` · `Craft` · `Exact text strings / Style descriptors / Composition`
- Card 4 — `4` · `Generate` · `gpt-image-2 (default) or gemini-3-pro / via fal.ai`
- Card 5 — `5` · `Capture` · `Optional .ctxillu.md sidecar / Persists style across sessions`
- Loopback label (italic): `next session reads prior spec`

Stage titles are bold and clearly larger than subtitles. Numbered circles are small, top-left of each card.

## User Preferences
- Standing principle from the skill itself: when an image is information-carrying, list every label in full — don't paraphrase or substitute "etc."
- The curved feedback arrow is the visual story; future sibling diagrams in this skill should preserve some equivalent "loop" or memory motif rather than treat the workflow as purely linear.
- Aesthetic register: technical but warm — explicitly avoid corporate-cold blue-on-white.

## Prompt
> A clean horizontal workflow diagram explaining the 'contextual-illustrator' skill, in a flat technical-illustration style. Warm cream/off-white background (#FAF6F0), deep navy strokes (#1F2A44), with restrained accents in sage green (#7A9E7E) and dusty coral (#C97B6E). Generous whitespace, no drop shadows. Subtle dotted-grid backdrop for technical feel.
>
> Title at top, large and bold: 'contextual-illustrator workflow'
> Subtitle below title, lighter weight: 'context-aware images with cross-session style memory'
>
> Five rounded-rectangle stage cards arranged left-to-right, connected by thin straight arrows pointing right. Each card has a small numbered circle in the upper-left, a bold stage title, and a multi-line subtitle in lighter weight beneath:
>
> Card 1 — number '1' — title 'Scan' — subtitle 'Find .ctxillu.md sidecars / Read nearby images'
> Card 2 — number '2' — title 'Analyze' — subtitle 'Surrounding content / Tone / Purpose / Placement'
> Card 3 — number '3' — title 'Craft' — subtitle 'Exact text strings / Style descriptors / Composition'
> Card 4 — number '4' — title 'Generate' — subtitle 'gpt-image-2 (default) or gemini-3-pro / via fal.ai'
> Card 5 — number '5' — title 'Capture' — subtitle 'Optional .ctxillu.md sidecar / Persists style across sessions'
>
> A larger curved arrow loops underneath all five cards, starting from the bottom-right of Card 5 and ending at the top-left of Card 1. This curved arrow is colored sage green (#7A9E7E) and labeled in the middle, in italic: 'next session reads prior spec'. This loopback is the visual centerpiece — make it noticeable but not garish.
>
> Sans-serif typography throughout (Inter or Söhne style). Stage titles are bold and clearly larger than subtitles. All text rendered legibly and accurately as written. Composition: the five cards take up roughly the upper 60% of the canvas, the curved feedback arrow occupies the lower 30%, with the title above and subtle margin around the edges. 16:9 landscape.

## Iteration Notes
- 2026-04-30 — initial generation; bootstrap of the skill's own README hero.
