# Contextual Illustrator

Claude Code skill for context-aware image generation using Gemini 3 Pro Image, with OpenRouter and fal.ai dual-backend support.

## Setup

### 1. Clone to skills directory

```bash
cd ~/.claude/skills
git clone <repo-url> contextual-illustrator
```

### 2. Configure API Key

Create `.env` in the skill root directory:

```bash
cd ~/.claude/skills/contextual-illustrator
cp .env.example .env
# Edit .env and fill in your key
```

Two backends are supported, configure at least one:

```env
# OpenRouter (recommended, no extra Python deps needed)
OPENROUTER_API_KEY=sk-or-v1-xxxx

# fal.ai
FAL_KEY=xxxx
```

If both keys are present, OpenRouter is used by default. You can force a backend with `--backend fal` or `--backend openrouter`.

Get your keys:
- OpenRouter: https://openrouter.ai/keys
- fal.ai: https://fal.ai/dashboard/keys

### 3. Install dependencies (fal.ai backend only)

OpenRouter backend uses Python stdlib only, no install needed.

If using fal.ai backend:

```bash
cd ~/.claude/skills/contextual-illustrator
uv venv
uv pip install fal-client
```

## Usage

The skill is automatically invoked by Claude Code when image generation is needed. You can also run the script directly:

```bash
cd ~/.claude/skills/contextual-illustrator

# Basic usage (auto-selects backend from .env)
uv run python scripts/generate_image.py "A sunset over mountains"

# With options
uv run python scripts/generate_image.py \
  "A clean minimal illustration of microservices architecture" \
  --aspect-ratio 16:9 \
  --resolution 2K \
  --output-format png \
  --output-dir ./output \
  --filename-prefix hero-image

# Force a specific backend
uv run python scripts/generate_image.py "A cat" --backend openrouter
```

### Parameters

| Parameter | Options | Default |
|---|---|---|
| `--aspect-ratio` | `auto`, `1:1`, `16:9`, `4:3`, `3:2`, `9:16`, etc. | `1:1` |
| `--resolution` | `1K`, `2K`, `4K` | `1K` |
| `--output-format` | `png`, `jpeg`, `webp` | `png` |
| `--num-images` | `1`-`4` | `1` |
| `--safety-tolerance` | `1`-`6` (fal.ai only) | `4` |
| `--backend` | `openrouter`, `fal` | auto-detect |

### Output

JSON to stdout:

```json
{
  "backend": "openrouter",
  "files": ["./output/hero-image.png"],
  "urls": [],
  "description": "..."
}
```

## File Structure

```
contextual-illustrator/
├── .env              # API keys (gitignored)
├── .env.example      # Template
├── .gitignore
├── SKILL.md          # Skill instructions for Claude Code
├── README.md
└── scripts/
    └── generate_image.py
```
