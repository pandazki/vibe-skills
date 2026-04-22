---
name: contextual-illustrator
description: >
  Generate contextual illustrations for documents, webpages, and any content using Gemini 3 Pro Image
  or OpenAI GPT-Image-2, via OpenRouter or fal.ai (auto-routed by API key).
  Use this skill whenever an image, illustration, or visual is needed in context — including but not limited to:
  document illustrations, blog post hero images, webpage banners, diagram placeholders, icon-style graphics,
  presentation visuals, or any scenario where visual content would enhance the output.
  This skill analyzes the surrounding context (text, existing images, tone, purpose) to generate
  images that fit naturally, rather than producing generic results from bare prompts.
---

# Contextual Illustrator

Generate context-aware illustrations using Gemini 3 Pro Image or OpenAI GPT-Image-2. Analyze the scene, infer what image is needed, and produce visuals that fit naturally into the surrounding content.

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

- **API Key**: The script auto-loads keys from `{SKILL_PATH}/.env` and routes to the appropriate backend:
  - `FAL_KEY` → fal.ai (preferred; required for default model `gpt-image-2`)
  - `OPENROUTER_API_KEY` → OpenRouter (Gemini 3 Pro only)
- **Python**: Always use `uv run` to execute the script. If dependencies are missing, run `cd {SKILL_PATH} && uv venv && uv pip install fal-client` — **never use bare pip install**.
- Use `--backend fal` or `--backend openrouter` to force a specific backend.

### 2. Analyze Context

Before crafting the prompt, reason through these dimensions:

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

**If style is explicitly specified** → follow it exactly.

**If style is inferable from context** (e.g., existing images, brand guidelines, document theme) → match that style. When generating multiple images in a session, maintain consistency by reusing the same style descriptors.

**If no style context exists** → default to the "elegant minimal" (素雅) baseline:

> Soft muted color palette, clean composition, subtle textures, restrained use of detail,
> generous whitespace, natural lighting, understated elegance.

Style descriptors to append to prompts for the default aesthetic:
- `soft muted colors, clean minimal composition, subtle texture`
- `elegant and understated, gentle natural lighting`
- `sophisticated simplicity, restrained palette`

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

GPT-Image-2 (default):

```bash
cd {SKILL_PATH} && uv run python scripts/generate_image.py \
  "Your crafted prompt here" \
  --aspect-ratio 16:9 \
  --quality high \
  --output-format png \
  --output-dir ./images \
  --filename-prefix descriptive-name
```

GPT-Image-2 edit (modify an existing image, optionally with a mask):

```bash
cd {SKILL_PATH} && uv run python scripts/generate_image.py \
  "Same scene, but replace the headline text with 'Hello World'" \
  --image-urls https://example.com/source.png \
  --mask-url https://example.com/mask.png \
  --output-dir ./images \
  --filename-prefix edited-hero
```

Gemini 3 Pro (opt-in):

```bash
cd {SKILL_PATH} && uv run python scripts/generate_image.py \
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

## Style Consistency Protocol

When generating multiple images in one session:

1. After the first image, record the style descriptors used.
2. For subsequent images, prepend the same style descriptors to maintain visual consistency.
3. If the user explicitly changes style mid-session, adopt the new style and apply it going forward.

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
