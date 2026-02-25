#!/usr/bin/env bash
# jina_fetch.sh — Wrapper for Jina Reader API (r.jina.ai / s.jina.ai)
# Usage:
#   jina_fetch.sh read  <url>   [options]
#   jina_fetch.sh search <query> [options]
#
# Options:
#   --json           Return JSON instead of markdown
#   --stream         Use streaming mode (for dynamic pages)
#   --selector <sel> Extract only matching CSS selector
#   --wait-for <sel> Wait for element before extracting
#   --remove <sel>   Remove elements matching selector
#   --no-cache       Bypass cached content
#   --no-images      Strip images from output
#   --timeout <sec>  Max wait time for page load
#   --key <key>      Jina API key (or set JINA_API_KEY env var)
#   --cookie <str>   Forward cookie string
#   --proxy <url>    Use proxy server
#   --locale <loc>   Browser locale (e.g. zh-CN)
#   --readerlm       Use ReaderLM-v2 (3x cost, higher quality)
#   --site <domain>  Restrict search to domain (search mode only)
#   -o <file>        Save output to file

set -euo pipefail

# Auto-load .env from skill directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
if [[ -f "$SKILL_DIR/.env" ]]; then
  set -a
  source "$SKILL_DIR/.env"
  set +a
fi

MODE=""
TARGET=""
HEADERS=()
OUTPUT=""
SITE_PARAM=""
METHOD="GET"

usage() {
  echo "Usage: $0 read <url> [options]"
  echo "       $0 search <query> [options]"
  echo ""
  echo "Options:"
  echo "  --json           JSON response"
  echo "  --stream         Streaming mode"
  echo "  --selector <s>   CSS target selector"
  echo "  --wait-for <s>   Wait for CSS selector"
  echo "  --remove <s>     Remove CSS selector"
  echo "  --no-cache       Bypass cache"
  echo "  --no-images      Strip images"
  echo "  --timeout <sec>  Page load timeout"
  echo "  --key <key>      API key (or JINA_API_KEY env)"
  echo "  --cookie <str>   Forward cookies"
  echo "  --proxy <url>    Proxy server"
  echo "  --locale <loc>   Browser locale"
  echo "  --readerlm       Use ReaderLM-v2"
  echo "  --site <domain>  Restrict search domain"
  echo "  -o <file>        Output file"
  exit 1
}

[[ $# -lt 2 ]] && usage

MODE="$1"
TARGET="$2"
shift 2

# Parse API key from env
if [[ -n "${JINA_API_KEY:-}" ]]; then
  HEADERS+=(-H "Authorization: Bearer $JINA_API_KEY")
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      HEADERS+=(-H "Accept: application/json")
      shift ;;
    --stream)
      HEADERS+=(-H "Accept: text/event-stream")
      shift ;;
    --selector)
      HEADERS+=(-H "X-Target-Selector: $2")
      shift 2 ;;
    --wait-for)
      HEADERS+=(-H "X-Wait-For-Selector: $2")
      shift 2 ;;
    --remove)
      HEADERS+=(-H "X-Remove-Selector: $2")
      shift 2 ;;
    --no-cache)
      HEADERS+=(-H "X-No-Cache: true")
      shift ;;
    --no-images)
      HEADERS+=(-H "X-With-Images: false")
      shift ;;
    --timeout)
      HEADERS+=(-H "X-Timeout: $2")
      shift 2 ;;
    --key)
      HEADERS+=(-H "Authorization: Bearer $2")
      shift 2 ;;
    --cookie)
      HEADERS+=(-H "X-Set-Cookie: $2")
      shift 2 ;;
    --proxy)
      HEADERS+=(-H "X-Proxy-Url: $2")
      shift 2 ;;
    --locale)
      HEADERS+=(-H "X-Locale: $2")
      shift 2 ;;
    --readerlm)
      HEADERS+=(-H "X-Use-Reader-LM-V2: true")
      shift ;;
    --site)
      SITE_PARAM="$2"
      shift 2 ;;
    -o)
      OUTPUT="$2"
      shift 2 ;;
    *)
      echo "Unknown option: $1" >&2
      usage ;;
  esac
done

build_url() {
  case "$MODE" in
    read)
      echo "https://r.jina.ai/${TARGET}"
      ;;
    search)
      local encoded
      encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TARGET'))" 2>/dev/null || echo "$TARGET")
      if [[ -n "$SITE_PARAM" ]]; then
        echo "https://s.jina.ai/${encoded}?site=${SITE_PARAM}"
      else
        echo "https://s.jina.ai/${encoded}"
      fi
      ;;
    *)
      echo "Unknown mode: $MODE. Use 'read' or 'search'." >&2
      exit 1
      ;;
  esac
}

URL=$(build_url)

if [[ -n "$OUTPUT" ]]; then
  curl -sS "${HEADERS[@]}" "$URL" -o "$OUTPUT"
  echo "Saved to $OUTPUT ($(wc -c < "$OUTPUT") bytes)"
else
  curl -sS "${HEADERS[@]}" "$URL"
fi
