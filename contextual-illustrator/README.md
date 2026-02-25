# Contextual Illustrator

Context-aware image generation skill using Gemini 3 Pro Image, with OpenRouter and fal.ai dual-backend support.

Analyzes surrounding content (text, tone, existing visuals, audience) to produce images that fit naturally into documents, blog posts, presentations, and more — rather than generating generic results from bare prompts.

## Configuration

Create `.env` in this directory (copy from `.env.example`), configure at least one backend:

```env
# OpenRouter (recommended, no extra Python deps)
OPENROUTER_API_KEY=sk-or-v1-xxxx

# fal.ai (requires: uv pip install fal-client)
FAL_KEY=xxxx
```

Get your keys:
- OpenRouter: https://openrouter.ai/keys
- fal.ai: https://fal.ai/dashboard/keys

## How It Works

1. Analyzes the surrounding context — purpose, content, tone, existing visuals
2. Determines appropriate style (explicit, inferred from context, or defaults to "elegant minimal")
3. Crafts a detailed generation prompt incorporating all context
4. Chooses parameters (aspect ratio, resolution, format) based on placement
5. Generates via `scripts/generate_image.py` and integrates into content

See `SKILL.md` for the full workflow instructions that Claude follows.
