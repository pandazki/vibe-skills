# Contextual Illustrator

Context-aware image generation skill supporting two models with OpenRouter and fal.ai backends:

- **Gemini 3 Pro Image** (default) — general illustrations, painterly/artistic work. OpenRouter or fal.ai.
- **OpenAI GPT-Image-2** — fine-grained typography, legible text, signage, UI mockups, and precise mask-based edits. fal.ai only. Invoke with `--model gpt-image-2`.

Analyzes surrounding content (text, tone, existing visuals, audience) to produce images that fit naturally into documents, blog posts, presentations, and more — rather than generating generic results from bare prompts.

## Configuration

Create `.env` in this directory (copy from `.env.example`), configure at least one backend:

```env
# fal.ai (recommended; required for the default gpt-image-2 model)
FAL_KEY=xxxx

# OpenRouter (fallback, Gemini 3 Pro only, no extra Python deps)
OPENROUTER_API_KEY=sk-or-v1-xxxx
```

Get your keys:
- fal.ai: https://fal.ai/dashboard/keys
- OpenRouter: https://openrouter.ai/keys

## How It Works

1. Analyzes the surrounding context — purpose, content, tone, existing visuals
2. Determines appropriate style (explicit, inferred from context, or defaults to "elegant minimal")
3. Crafts a detailed generation prompt incorporating all context
4. Chooses parameters (aspect ratio, resolution, format) based on placement
5. Generates via `scripts/generate_image.py` and integrates into content

See `SKILL.md` for the full workflow instructions that Claude follows.
