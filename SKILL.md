---
name: contextual-illustrator
description: >
  Generate contextual illustrations for documents, webpages, and any content using Gemini 3 Pro Image
  via OpenRouter or fal.ai (auto-routed by API key).
  Use this skill whenever an image, illustration, or visual is needed in context — including but not limited to:
  document illustrations, blog post hero images, webpage banners, diagram placeholders, icon-style graphics,
  presentation visuals, or any scenario where visual content would enhance the output.
  This skill analyzes the surrounding context (text, existing images, tone, purpose) to generate
  images that fit naturally, rather than producing generic results from bare prompts.
---

# Contextual Illustrator

Generate context-aware illustrations using Gemini 3 Pro Image. Analyze the scene, infer what image is needed, and produce visuals that fit naturally into the surrounding content.

**Isolation**: Delegate image generation to a sub-agent (Task tool) when possible, to avoid polluting the main conversation context with image generation details. Pass the sub-agent the relevant context summary, style notes, and output path.

## Workflow

### 1. Environment

- **API Key**: 脚本自动从 skill 根目录的 `.env` 加载，根据可用 key 自动路由后端：
  - `OPENROUTER_API_KEY` → OpenRouter（优先，无需额外依赖）
  - `FAL_KEY` → fal.ai
  - 都没有 → 报错提示用户配置
- **Python**: 始终用 `uv run` 执行脚本。如果报错缺少依赖，则在 skill 目录下执行 `cd {SKILL_PATH} && uv venv && uv pip install fal-client`，**不要用 pip install**。（OpenRouter 后端无需额外依赖）
- 可通过 `--backend fal` 或 `--backend openrouter` 强制指定后端。

### 2. Analyze Context

Before crafting the prompt, reason through these dimensions:

- **Purpose**: What role does this image serve? (hero image, inline illustration, icon, diagram, decorative)
- **Content alignment**: What is the surrounding text about? What key concepts should the image convey?
- **Existing visuals**: Are there other images nearby? Match their style, color palette, and mood.
- **Audience & tone**: Technical docs → clean/minimal. Marketing → vibrant/engaging. Personal blog → warm/expressive.
- **Placement & size**: Where will the image appear? This determines aspect ratio.

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
| `aspect_ratio` | Match placement: `16:9` for hero/banner, `1:1` for inline/thumbnail, `4:3` for document, `9:16` for mobile/sidebar, `auto` if unsure |
| `resolution` | `1K` for web/inline, `2K` for print/hero, `4K` only when explicitly needed |
| `output_format` | `png` for illustrations with transparency needs, `webp` for web, `jpeg` for photos |
| `num_images` | Default `1`. Use `2` when offering alternatives. |
| `filename_prefix` | Descriptive name reflecting content, e.g. `hero-microservices`, `fig1-architecture` |
| `output_dir` | Place images near the content that uses them |

### 6. Generate

```bash
cd {SKILL_PATH} && uv run python scripts/generate_image.py \
  "Your crafted prompt here" \
  --aspect-ratio 16:9 \
  --resolution 1K \
  --output-format png \
  --output-dir ./images \
  --filename-prefix descriptive-name
```

The script outputs JSON with `backend` (used backend), `files` (local paths), `urls` (remote URLs), and `description`.

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

**Model**: Gemini 3 Pro Image Preview (`google/gemini-3-pro-image-preview` on OpenRouter, `fal-ai/gemini-3-pro-image-preview` on fal.ai)

**Aspect ratios**: `auto`, `21:9`, `16:9`, `3:2`, `4:3`, `5:4`, `1:1`, `4:5`, `3:4`, `2:3`, `9:16`

**Resolutions**: `1K`, `2K`, `4K`（both backends）

**Formats**: `png`, `jpeg`, `webp`

**Safety tolerance**: `1` (strictest) to `6` (least strict), default `4`（fal.ai only）
