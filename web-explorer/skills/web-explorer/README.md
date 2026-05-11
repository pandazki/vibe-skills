# Web Explorer

Access the internet to read, search, and research — powered by Jina APIs.

Three modes:
- **Read** — fetch any URL as clean, LLM-friendly markdown (handles JS-rendered pages, SPAs, PDFs)
- **Search** — web search returning top results with full extracted content
- **Deep Research** — agentic multi-step search and reasoning for complex questions

## Configuration

Create `.env` in this directory (copy from `.env.example`):

```env
JINA_API_KEY=jina_xxxx
```

Get a key at https://jina.ai/ — free tier includes 10M tokens.

## How It Works

1. Pre-checks `.env` for a valid API key (asks the user if missing, writes it once)
2. Picks the right mode based on the task (read / search / deep-research)
3. Calls the provider API via the helper script or curl
4. Returns clean content for integration into the conversation

See `SKILL.md` for the full workflow instructions that Claude follows.
