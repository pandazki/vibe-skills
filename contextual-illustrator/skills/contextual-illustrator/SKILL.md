---
name: contextual-illustrator
description: >
  Generate contextual illustrations for documents, webpages, and any content using OpenAI GPT-Image-2
  (default) or Gemini 3 Pro Image, via fal.ai or OpenRouter (auto-routed by API key).
  Use this skill whenever an image, illustration, or visual is needed in context — including but not limited to:
  document illustrations, blog post hero images, webpage banners, diagram placeholders, icon-style graphics,
  presentation visuals, or any scenario where visual content would enhance the output.
  This skill analyzes the surrounding context (text, existing images, tone, purpose) to generate
  images that fit naturally, rather than producing generic results from bare prompts.
---

# Contextual Illustrator

Generate context-aware illustrations using OpenAI GPT-Image-2 (default) or Gemini 3 Pro Image. Analyze the scene, infer what image is needed, and produce visuals that fit naturally into the surrounding content.

**Isolation**: Delegate image generation to a sub-agent (Task tool) when possible, to avoid polluting the main conversation context with image generation details. Pass the sub-agent the relevant context summary, style notes, and output path.

## Workflow

### 0. Pre-check: API Key

Before any generation, verify that `{SKILL_PATH}/.env` contains at least one valid API key (`FAL_KEY` preferred, `OPENROUTER_API_KEY` as fallback).

If the `.env` file is missing or contains no keys:
1. Ask the user to provide an API key (fal.ai recommended — it's required for the default `gpt-image-2` model).
2. Once the user provides the key, write it to `{SKILL_PATH}/.env`:
   - `FAL_KEY=<key>` for fal.ai
   - `OPENROUTER_API_KEY=<key>` for OpenRouter (Gemini 3 Pro only)
3. This only needs to happen once — the key persists across sessions.

Key sources:
- fal.ai: https://fal.ai/dashboard/keys
- OpenRouter: https://openrouter.ai/keys

### 1. Environment

**API key**. All three runtime scripts auto-load keys from `{SKILL_PATH}/.env` and route to the appropriate backend:

- `FAL_KEY` → fal.ai (preferred; required for default model `gpt-image-2`)
- `OPENROUTER_API_KEY` → OpenRouter (Gemini 3 Pro only)

Force a specific backend with `--backend fal` or `--backend openrouter`.

**Pick a runtime**. Three interchangeable scripts ship in `scripts/` — same flags, same JSON output. Use whichever fits the host; **don't install a runtime that isn't already there**.

| Script | Requires | Notes |
|---|---|---|
| `scripts/generate_image.py` | Python 3.10+ and `fal-client` | Most fully tested path. |
| `scripts/generate_image.mjs` | Node ≥ 18 or Bun, zero npm deps | Zero setup once the runtime is on PATH. Bun's startup is a touch faster. |
| `scripts/generate_image.sh` | bash, `curl`, `jq` | Uses fal.ai sync mode (`https://fal.run/<endpoint>`) — one POST per call, no polling. Perfectly fine for production / CI / minimal containers. |

**Pick by probing — first hit wins**:

1. `{SKILL_PATH}/.venv/bin/python -c 'import fal_client'` succeeds → Python.
2. `command -v bun` or `command -v node` → JS.
3. `command -v curl && command -v jq` → bash.
4. None of the above → bootstrap Python: `cd {SKILL_PATH} && uv venv && uv pip install fal-client`, then invoke `{SKILL_PATH}/.venv/bin/python …`.

Probe once per session and stay with the choice — don't re-probe between images. If the chosen runtime starts failing mid-session (Python venv breaks, etc.), fall through the list rather than fighting to fix it.

**Python setup**: if `{SKILL_PATH}/.venv` is missing or its libpython link is stale (`dyld: Library not loaded` errors), rebuild with `cd {SKILL_PATH} && uv venv && uv pip install fal-client`. Then invoke directly with `{SKILL_PATH}/.venv/bin/python scripts/generate_image.py …` — that's more reliable than `uv run`, which doesn't auto-discover an ad-hoc `.venv` without a `pyproject.toml`.

**Bun note**: `bun scripts/generate_image.mjs …` works the same as `node`. Bun's faster startup is nice for CI loops.

**Bash note**: macOS ships bash 3.2, which the script supports. Confirm `jq` is installed (`brew install jq` if not).

### 2. Analyze Context

**First, scan for prior sidecars.** Glob the target output directory and its immediate parent for `*.ctxillu.md` files (e.g., `./images/*.ctxillu.md`, `./*.ctxillu.md`). If any exist, read them in full before crafting the prompt — they capture committed style, palette, text density, and standing user preferences from prior generations in this project. Treat them as authoritative for this project's house style and override generic inference from content alone.

Then reason through these dimensions:

- **Purpose**: What role does this image serve? (hero image, inline illustration, icon, diagram, decorative)
- **Content alignment**: What is the surrounding text about? What key concepts should the image convey?
- **Existing visuals**: Are there other images nearby? Match their style, color palette, and mood.
- **Audience & tone**: Technical docs → clean/minimal. Marketing → vibrant/engaging. Personal blog → warm/expressive.
- **Placement & size**: Where will the image appear? This determines aspect ratio.

### 2.5. Choose the Model

| Model | When to pick it | Backends |
|---|---|---|
| `gpt-image-2` (default) | General use. Strong at **fine-grained typography, legible text, labels, signage, UI mockups with real copy, diagrams with text**, and precise mask-based edits to existing images. | fal.ai only |
| `gemini-3-pro` | Opt in for painterly/artistic illustrations, broad stylistic range, or when you specifically want Gemini's aesthetic. Also the only option on OpenRouter. | OpenRouter, fal.ai |

Rules of thumb:
- Default to `gpt-image-2` unless the user asks otherwise.
- Need to edit an existing image (replace a region / restyle with a reference) → `gpt-image-2` with `--image-urls` (and optional `--mask-url`).
- Only OpenRouter key configured → `gemini-3-pro` (script will tell you if `gpt-image-2` isn't reachable).

### 3. Determine Style

Resolve style in this priority order — the higher item always wins:

1. **Explicit user instruction this turn** — follow exactly.
2. **Sibling sidecars** (`.ctxillu.md` discovered in step 2) — adopt their style descriptors verbatim. This is how a project keeps a coherent look across many illustrations over weeks or months. If multiple sidecars disagree, prefer the most recent one but flag the divergence to the user.
3. **Inferred from context** — existing images nearby, brand guidelines, document theme.
4. **"Elegant minimal" (素雅) baseline** if nothing else applies:

> Soft muted color palette, clean composition, subtle textures, restrained use of detail,
> generous whitespace, natural lighting, understated elegance.

Style descriptors to append to prompts for the default aesthetic:
- `soft muted colors, clean minimal composition, subtle texture`
- `elegant and understated, gentle natural lighting`
- `sophisticated simplicity, restrained palette`

When generating multiple images in a session, reuse the same style descriptors so the set looks like one project, not five.

### 4. Craft the Prompt

Build a detailed image generation prompt that incorporates the analysis above. A good prompt includes:

1. **Subject**: What the image depicts (derived from context analysis, not just user words)
2. **Style**: Visual treatment (from step 3)
3. **Composition**: Framing, perspective, layout considerations
4. **Mood/Atmosphere**: Emotional tone that matches the surrounding content
5. **Technical details**: Medium, rendering style, lighting if relevant

**Example** — user is writing a technical blog post about microservices:

> A clean architectural diagram-style illustration showing interconnected service nodes,
> each represented as simple geometric shapes connected by thin lines, soft muted blue
> and gray palette, minimal flat design, generous whitespace, technical yet approachable.

#### On text density and content richness

Match text density to **what the image is for** — not to outdated beliefs about what image models can do. Both `gpt-image-2` and `gemini-3-pro` render text and information-dense layouts substantially better than diffusion-era models: labels, tables, headlines, small annotations all come out legible. A common failure mode here is the agent reflexively shrinking text out of habit ("a dashboard with some metrics"), not the model failing on a fully-spelled-out prompt. Recalibrate.

There are two regimes, and the right amount of text in each is very different:

- **Information-carrying images** (UI mockups, dashboards, infographics, diagrams with labels, charts with annotations, document or page renderings) — pursue **accuracy and completeness**. List the exact strings in full: if the surrounding doc has a 5-item list, name all 5; if it has three KPI cards, write all three values. Don't paraphrase, don't substitute "etc.", don't fall back to placeholder squiggles. The model will render what you specify.
- **Atmospheric / decorative images** (hero photography, abstract banners, mood pieces, illustrative spot-art) — little or no rendered text is normal and often preferred. Don't pad with copy just to fill space; let the surrounding page handle headlines.

If the user has expressed a density preference (`minimal` / `balanced` / `dense`) in this session or in a sidecar, respect it.

**Bad** (information-carrying, vague): "A blog hero showing a SaaS dashboard with some metrics."
**Good** (information-carrying, specified): "A blog hero showing a SaaS dashboard titled 'Sales Pipeline — Q4 2025', with sidebar items 'Overview / Deals / Contacts / Reports / Settings' and three KPI cards: 'Pipeline: $4.2M', 'Closed Won: $1.8M', 'Win Rate: 38%'."

**Bad** (information-carrying, vague): "A diagram of an authentication flow."
**Good** (information-carrying, specified): "A sequence diagram with four labeled lanes — 'Browser', 'API Gateway', 'Auth Service', 'Database' — and labeled arrows between them: 'POST /login', 'verify credentials', 'SELECT user', 'JWT token', '200 OK'."

### 5. Choose Parameters

| Parameter | How to decide |
|---|---|
| `model` | `gpt-image-2` (default) or `gemini-3-pro`. See step 2.5. |
| `aspect_ratio` | Match placement: `16:9` for hero/banner, `1:1` for inline/thumbnail, `4:3` for document, `9:16` for mobile/sidebar, `auto` if unsure. For `gpt-image-2`, the ratio maps to a fal.ai preset (`landscape_4_3`, `square_hd`, etc.). |
| `resolution` | **Gemini only.** `1K` for web/inline, `2K` for print/hero, `4K` only when explicitly needed. |
| `quality` | **GPT-Image-2 only.** `low` / `medium` / `high` (default `high`). Directly affects cost — drop to `medium` for drafts. |
| `image_size` | **GPT-Image-2 only, optional.** Preset name (`landscape_4_3`, `square_hd`, …) or explicit `WxH` (e.g. `1024x1024`). Overrides the `aspect_ratio` mapping. |
| `image_urls` / `mask_url` | **GPT-Image-2 only.** Supply reference URLs to switch to the edit endpoint; add a mask to constrain edits. |
| `output_format` | `png` for illustrations with transparency needs, `webp` for web, `jpeg` for photos |
| `num_images` | Default `1`. Use `2` when offering alternatives. |
| `filename_prefix` | Descriptive name reflecting content, e.g. `hero-microservices`, `fig1-architecture` |
| `output_dir` | Place images near the content that uses them |

### 6. Generate

The examples below use the Python script. To use the JS or bash runtime, swap the invocation only — flags and JSON output are identical:

| Runtime | Replace `.venv/bin/python scripts/generate_image.py` with |
|---|---|
| Node / Bun | `node scripts/generate_image.mjs` (or `bun ...`) |
| bash + curl | `bash scripts/generate_image.sh` |

GPT-Image-2 (default):

```bash
cd {SKILL_PATH} && .venv/bin/python scripts/generate_image.py \
  "Your crafted prompt here" \
  --aspect-ratio 16:9 \
  --quality high \
  --output-format png \
  --output-dir ./images \
  --filename-prefix descriptive-name
```

GPT-Image-2 edit (modify an existing image, optionally with a mask):

```bash
cd {SKILL_PATH} && .venv/bin/python scripts/generate_image.py \
  "Same scene, but replace the headline text with 'Hello World'" \
  --image-urls https://example.com/source.png \
  --mask-url https://example.com/mask.png \
  --output-dir ./images \
  --filename-prefix edited-hero
```

Gemini 3 Pro (opt-in):

```bash
cd {SKILL_PATH} && .venv/bin/python scripts/generate_image.py \
  "Your crafted prompt here" \
  --model gemini-3-pro \
  --aspect-ratio 16:9 \
  --resolution 1K \
  --output-format png \
  --output-dir ./images \
  --filename-prefix descriptive-name
```

The script outputs JSON with `backend`, `model`, `files` (local paths), `urls` (remote URLs), and `description`. For `gpt-image-2` the `endpoint` field also records whether the text-to-image or edit endpoint was used.

### 7. Integrate

After generating, integrate the image into the content:
- Insert the image reference at the appropriate location
- Add meaningful alt text derived from the prompt and context
- Verify the image fits the surrounding content's flow

### 8. Capture Spec (judgment call — default off)

A sidecar is a small markdown file written next to the image — `<image-stem>.ctxillu.md` — that records the production decisions for that image: subject, style, exact text strings, user preferences, and the prompt used. Future generations in the same project can read these sidecars (step 2) to keep the look consistent over time and across sessions.

Sidecars are **not** written by default. Write one only when the work has a future — most asks are one-off and don't need the housekeeping. Use judgment based on the rubric below; when uncertain, generate first and ask a single short question.

**Write a sidecar when any of these is true:**
- A `.ctxillu.md` already exists in the target directory (the project is already using sidecars — keep up the convention).
- The user has expressed style preferences this session (palette, mood, brand tone, text density, font choices) that should outlive this turn.
- The image lives in a long-lived structure: a repo, blog, doc site, presentation deck, design system — not a scratch / tmp / `~/Downloads` dir.
- The image is part of a series (`fig1` + `fig2`, hero + inline, cover + thumbnails) where future images need to match.
- The user explicitly asked to "match", "stay consistent with", or "use the same style as" prior work.
- The user is iterating — regenerating with adjustments — which itself signals the image has a lifecycle.

**Skip when** clearly one-off: throwaway visual, scratch directory, single quick request with no broader context, generated content that won't be reused.

**If genuinely ambiguous** (e.g., reasonable doc-level project but unclear whether more images are coming), generate and integrate the image first, then ask once — briefly: *"Want me to drop a `.ctxillu.md` next to it? It saves the style and text decisions so the next image in this set can match."* One question, easy yes/no, don't push.

#### Sidecar template

Write the sidecar with the `Write` tool. Use this template — fill every section that applies, omit ones that don't, keep it tight (aim for under 60 lines):

```markdown
---
image: <filename>.png
generated_at: <ISO 8601 UTC, e.g. 2026-04-30T14:22:00Z>
model: <gpt-image-2 | gemini-3-pro>
backend: <fal | openrouter>
aspect_ratio: <e.g. 16:9>
quality: <low | medium | high>           # gpt-image-2 only
resolution: <1K | 2K | 4K>               # gemini-3-pro only
text_density: <minimal | balanced | dense>  # only when image carries text
---

# Spec: <filename>

## Context
Where this image is used and what surrounding content it illustrates.

## Subject
What the image depicts.

## Style
Visual treatment — palette, mood, medium, references. Phrase descriptors so they can be reused **verbatim** in future prompts (e.g. "soft muted blue + warm gray, flat geometric, generous whitespace, gentle natural lighting").

## Composition
Framing, perspective, layout choices.

## Text & Typography
Exact strings rendered in the image, density preference, font character.

## User Preferences
Standing preferences from the user that should persist across regenerations. Quote where useful — e.g. *"don't use cartoon styles"*, *"match brand color #4A90E2"*, *"prefer dense labels over abstract shapes"*.

## Prompt
> The exact prompt sent to the model.

## Iteration Notes
(optional — only when the image is regenerated)
- 2026-04-30 — initial generation
```

#### Regenerating an image that already has a sidecar

If a sidecar already exists for the filename being overwritten:

1. Read the existing sidecar first.
2. Refresh the **Context / Subject / Style / Composition / Text & Typography / Prompt** sections to reflect the new state.
3. **Preserve User Preferences** — only remove an entry if the user explicitly retracted it.
4. Append a one-line entry to **Iteration Notes** with date and what changed (e.g., `2026-04-30 — switched palette from cool blue/gray to warm earth tones at user's request`).

This way the sidecar acts as a living spec rather than a frozen log.

## Style Consistency Protocol

**Within a session** — after the first image, record the style descriptors used and reuse them verbatim for subsequent images. If the user changes style mid-session, adopt the new style going forward.

**Across sessions** — sidecars (`.ctxillu.md`, see step 8) carry style continuity. When step 2 finds existing sidecars in the target directory, they are the source of truth for "what this project looks like." Adopt their descriptors verbatim before falling back to inference or defaults.

## API Reference

**Models**:
- Gemini 3 Pro Image Preview — `google/gemini-3-pro-image-preview` (OpenRouter) / `fal-ai/gemini-3-pro-image-preview` (fal.ai)
- OpenAI GPT-Image-2 — `openai/gpt-image-2` and `openai/gpt-image-2/edit` (fal.ai only)

**Aspect ratios** (both models, via `--aspect-ratio`): `auto`, `21:9`, `16:9`, `3:2`, `4:3`, `5:4`, `1:1`, `4:5`, `3:4`, `2:3`, `9:16`. For `gpt-image-2` the ratio is mapped to a fal.ai preset (`landscape_16_9`, `landscape_4_3`, `square_hd`, `portrait_4_3`, `portrait_16_9`); use `--image-size` to override with an explicit preset or `WxH`.

**Resolutions** (Gemini only): `1K`, `2K`, `4K`

**Quality** (GPT-Image-2 only): `low`, `medium`, `high` (default). Directly affects token cost.

**Formats**: `png`, `jpeg`, `webp`

**Safety tolerance** (Gemini on fal.ai only): `1` (strictest) to `6` (least strict), default `4`

**GPT-Image-2 image_size constraints** (fal.ai): both dimensions must be multiples of 16, max edge 3840px, aspect ratio ≤ 3:1, total pixels between 655,360 and 8,294,400.
