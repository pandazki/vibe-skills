---
name: web-explorer
description: >
  Access the internet to read, search, and research. Use this skill whenever you need web content —
  reading a webpage or article, searching for information, or conducting deep multi-step research.
  Converts any URL into clean LLM-friendly markdown, searches the web with full content extraction,
  and supports agentic deep research for complex questions requiring multiple rounds of search and reasoning.
---

# Web Explorer

Access the internet to read, search, and research. Fetch any URL as clean markdown, search the web with full content extraction, or run deep multi-step research for complex questions.

**Isolation**: Delegate web fetching to a sub-agent (Task tool) when possible, to keep the main conversation context clean. Pass the sub-agent the URL/query, desired mode, and output instructions.

## Workflow

### 0. Pre-check: API Key

Before any web access, check that `{SKILL_PATH}/.env` contains a valid provider API key.

If the `.env` file is missing or contains no key:
1. Ask the user to provide a Jina API key (free tier includes 10M tokens).
2. Once provided, write it to `{SKILL_PATH}/.env`:
   - `JINA_API_KEY=<key>`
3. This only needs to happen once — the key persists across sessions.

Get a key: https://jina.ai/ (sign up → API keys)

### 1. Choose Mode

| Mode | When to use | Latency |
|------|-------------|---------|
| **read** | You have a specific URL and need its content | ~2s |
| **search** | You need to find information on a topic | ~2.5s |
| **deep-research** | Complex question requiring multi-step search and reasoning | ~60s |

### 2. Read — Fetch a URL

Convert any URL to clean, LLM-friendly markdown. Handles JavaScript-rendered pages, SPAs, and PDFs.

```bash
# Basic read
cd {SKILL_PATH} && bash scripts/jina_fetch.sh read "https://example.com"

# JSON response (structured: url, title, content, timestamp)
cd {SKILL_PATH} && bash scripts/jina_fetch.sh read "https://example.com" --json

# Extract specific content via CSS selector
cd {SKILL_PATH} && bash scripts/jina_fetch.sh read "https://example.com" --selector "article.main"

# Save to file
cd {SKILL_PATH} && bash scripts/jina_fetch.sh read "https://example.com" -o output.md
```

**Detail levels** — choose based on the task:

| Level | Options | When to use |
|-------|---------|-------------|
| Quick | (default) | Skim or extract key info from a page |
| Focused | `--selector <css>` | Only need a specific section (article body, table, etc.) |
| Full | `--json` | Need metadata (title, timestamp) alongside content |
| Streaming | `--stream` | Dynamic/slow pages — progressive content extraction |

**Advanced options**:
- `--no-cache` — bypass cache for fresh content
- `--no-images` — strip images for text-only extraction
- `--timeout <sec>` — increase timeout for slow pages
- `--wait-for <css>` — wait for a specific element before extracting (useful for SPAs)
- `--locale <code>` — set browser locale (e.g. `zh-CN` for Chinese content)
- `--readerlm` — use ReaderLM-v2 for higher quality extraction (3x cost)
- `--cookie <str>` — forward cookies for authenticated pages
- `--proxy <url>` — route through a proxy

Full header reference: [references/reader-headers.md](references/reader-headers.md)

**SPA tips**: Hash routes (`#/path`) → use curl POST directly. Slow pages → `--timeout 30`. Dynamic content → `--wait-for "#content"` or `--stream`.

### 3. Search — Find Information

Search the web and get top 5 results with full extracted content.

```bash
# Basic search
cd {SKILL_PATH} && bash scripts/jina_fetch.sh search "latest developments in quantum computing"

# JSON response (structured results)
cd {SKILL_PATH} && bash scripts/jina_fetch.sh search "React server components" --json

# Restrict to a specific site
cd {SKILL_PATH} && bash scripts/jina_fetch.sh search "authentication guide" --site docs.example.com
```

**Options**:
- `--json` — structured JSON with url, title, content per result
- `--site <domain>` — restrict results to a specific domain
- `--no-cache` — bypass cache for the freshest results

### 4. Deep Research — Multi-step Investigation

For complex questions that require multiple searches, reading, reasoning, and iteration. The provider autonomously searches, reads pages, and synthesizes a comprehensive answer.

Load the API key from `.env` and call the DeepSearch endpoint:

```bash
cd {SKILL_PATH} && source .env && curl -sS -X POST https://deepsearch.jina.ai/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JINA_API_KEY" \
  -d '{
    "model": "jina-deepsearch-v1",
    "messages": [
      {"role": "user", "content": "Your complex research question here"}
    ],
    "stream": false
  }'
```

**When to use deep research vs. search**:
- **Search**: factual lookups, recent news, specific documentation
- **Deep research**: comparative analysis, "state of the art" surveys, questions needing multiple sources and reasoning

**Note**: Deep research has ~60s latency and higher token cost. Default to search unless the question genuinely needs multi-step reasoning.

### 5. Integrate Results

After fetching content:
- Summarize or extract the relevant parts for the user's task
- Cite sources with URLs when presenting information
- If the content is too long, focus on the sections most relevant to the question

## Provider

Currently supported: **Jina** (Reader, Search, DeepSearch APIs). Future providers can be added behind the same read/search/research interface.

**Rate limits**:

| Mode | Free key | Paid |
|------|----------|------|
| Read | 500 RPM | 5,000 RPM |
| Search | 100 RPM | 1,000 RPM |
| Deep Research | 50 RPM | 500 RPM |

Free tier: 10M tokens. Paid: $50 for 1B tokens.
