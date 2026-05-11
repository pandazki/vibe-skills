#!/usr/bin/env bash
# Generate images via fal.ai or OpenRouter — same flags + JSON output as
# scripts/generate_image.py. Pure shell: requires bash 4+, curl, and jq.
#
# Uses fal.ai sync mode (https://fal.run/<endpoint>) so a single POST returns
# the final result JSON — no queue polling.

set -euo pipefail

# ---------------------------------------------------------------------------
# defaults
# ---------------------------------------------------------------------------

PROMPT=""
MODEL="gpt-image-2"
NUM_IMAGES=1
ASPECT_RATIO="1:1"
OUTPUT_FORMAT="png"
RESOLUTION="1K"
SAFETY_TOLERANCE="4"
SEED=""
QUALITY="high"
IMAGE_SIZE=""
IMAGE_URLS=()
MASK_URL=""
OUTPUT_DIR="."
FILENAME_PREFIX="illustration"
BACKEND=""

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

err() { printf '%s\n' "$*" >&2; }
die() { err "ERROR: $*"; exit 1; }
log() { err "$*"; }

usage() {
  cat <<'EOF'
Usage: generate_image.sh <prompt> [flags]

Same flags as scripts/generate_image.py:
  --model {gemini-3-pro|gpt-image-2}     default gpt-image-2
  --num-images {1|2|3|4}                 default 1
  --aspect-ratio {auto|21:9|16:9|3:2|4:3|5:4|1:1|4:5|3:4|2:3|9:16}
  --output-format {jpeg|png|webp}         default png
  --resolution {1K|2K|4K}                 Gemini only, default 1K
  --safety-tolerance {1..6}               Gemini fal only, default 4
  --seed <int>                            Gemini fal only
  --quality {low|medium|high}             GPT-Image-2 only, default high
  --image-size <preset|WxH>               GPT-Image-2 only
  --image-urls <url> [<url> ...]          GPT-Image-2 edit
  --mask-url <url>                        GPT-Image-2 edit
  --output-dir <path>                     default .
  --filename-prefix <name>                default illustration
  --backend {fal|openrouter}              default auto-detect from .env

Requires: bash 4+, curl, jq.
EOF
}

valid_in() {
  local needle="$1"; shift
  local v
  for v in "$@"; do [[ "$v" == "$needle" ]] && return 0; done
  return 1
}

is_remote_url() {
  [[ "$1" != data:* ]]
}

# ---------------------------------------------------------------------------
# argv parsing
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --model)            MODEL="$2"; shift 2 ;;
    --num-images)       NUM_IMAGES="$2"; shift 2 ;;
    --aspect-ratio)     ASPECT_RATIO="$2"; shift 2 ;;
    --output-format)    OUTPUT_FORMAT="$2"; shift 2 ;;
    --resolution)       RESOLUTION="$2"; shift 2 ;;
    --safety-tolerance) SAFETY_TOLERANCE="$2"; shift 2 ;;
    --seed)             SEED="$2"; shift 2 ;;
    --quality)          QUALITY="$2"; shift 2 ;;
    --image-size)       IMAGE_SIZE="$2"; shift 2 ;;
    --mask-url)         MASK_URL="$2"; shift 2 ;;
    --output-dir)       OUTPUT_DIR="$2"; shift 2 ;;
    --filename-prefix)  FILENAME_PREFIX="$2"; shift 2 ;;
    --backend)          BACKEND="$2"; shift 2 ;;
    --image-urls)
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do
        IMAGE_URLS+=("$1"); shift
      done
      ;;
    --*) die "unknown flag: $1" ;;
    *)
      if [[ -z "$PROMPT" ]]; then
        PROMPT="$1"; shift
      else
        die "unexpected positional argument: $1"
      fi
      ;;
  esac
done

if [[ -z "$PROMPT" ]]; then
  usage >&2
  die "prompt is required"
fi

valid_in "$MODEL" gemini-3-pro gpt-image-2 || die "--model must be gemini-3-pro or gpt-image-2"
valid_in "$NUM_IMAGES" 1 2 3 4 || die "--num-images must be 1-4"
valid_in "$ASPECT_RATIO" auto 21:9 16:9 3:2 4:3 5:4 1:1 4:5 3:4 2:3 9:16 || die "--aspect-ratio invalid"
valid_in "$OUTPUT_FORMAT" jpeg png webp || die "--output-format invalid"
valid_in "$RESOLUTION" 1K 2K 4K || die "--resolution invalid"
valid_in "$SAFETY_TOLERANCE" 1 2 3 4 5 6 || die "--safety-tolerance invalid"
valid_in "$QUALITY" low medium high || die "--quality invalid"
[[ -n "$BACKEND" ]] && { valid_in "$BACKEND" fal openrouter || die "--backend invalid"; }
[[ -n "$SEED" && ! "$SEED" =~ ^-?[0-9]+$ ]] && die "--seed must be an integer"

command -v curl >/dev/null 2>&1 || die "curl is required but not installed"
command -v jq   >/dev/null 2>&1 || die "jq is required but not installed (https://jqlang.github.io/jq/)"

# ---------------------------------------------------------------------------
# .env loading (skill root first, then walk up from cwd)
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"

find_env_file() {
  if [[ -f "$SKILL_ROOT/.env" ]]; then
    printf '%s' "$SKILL_ROOT/.env"
    return
  fi
  local p
  p="$(pwd)"
  while :; do
    if [[ -f "$p/.env" ]]; then
      printf '%s' "$p/.env"
      return
    fi
    [[ "$p" == "/" || -z "$p" ]] && return
    p="$(dirname "$p")"
  done
}

strip_quotes() {
  local v="$1"
  case "$v" in
    \"*\") v="${v#\"}"; v="${v%\"}" ;;
    \'*\') v="${v#\'}"; v="${v%\'}" ;;
  esac
  printf '%s' "$v"
}

load_env() {
  local envfile line val
  envfile="$(find_env_file)"
  [[ -z "$envfile" ]] && return
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    # ltrim
    line="${line#"${line%%[![:space:]]*}"}"
    # rtrim
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    case "$line" in
      FAL_KEY=*)
        val="$(strip_quotes "${line#*=}")"
        if [[ -z "${FAL_KEY:-}" && -n "$val" ]]; then
          export FAL_KEY="$val"
        fi
        ;;
      OPENROUTER_API_KEY=*)
        val="$(strip_quotes "${line#*=}")"
        if [[ -z "${OPENROUTER_API_KEY:-}" && -n "$val" ]]; then
          export OPENROUTER_API_KEY="$val"
        fi
        ;;
    esac
  done < "$envfile"
}

load_env

# ---------------------------------------------------------------------------
# backend selection
# ---------------------------------------------------------------------------

if [[ -z "$BACKEND" ]]; then
  if   [[ -n "${FAL_KEY:-}"            ]]; then BACKEND="fal"
  elif [[ -n "${OPENROUTER_API_KEY:-}" ]]; then BACKEND="openrouter"
  else                                          BACKEND="none"
  fi
fi

if [[ "$MODEL" == "gpt-image-2" ]]; then
  if [[ "$BACKEND" == "openrouter" ]]; then
    [[ -z "${FAL_KEY:-}" ]] && die "--model gpt-image-2 requires FAL_KEY (not available on OpenRouter)."
    log "[router] Note: gpt-image-2 is fal.ai-only — switching backend to fal."
    BACKEND="fal"
  elif [[ "$BACKEND" == "none" ]]; then
    die "--model gpt-image-2 requires FAL_KEY in .env. Get one at https://fal.ai/dashboard/keys"
  fi
fi

if [[ "$BACKEND" == "none" ]]; then
  err "ERROR: No API key found in .env file."
  err "Please add one of the following to the .env file in the skill directory:"
  err "  OPENROUTER_API_KEY=your_openrouter_key   (https://openrouter.ai/keys)"
  err "  FAL_KEY=your_fal_key                     (https://fal.ai/dashboard/keys)"
  exit 1
fi

log "[router] model=$MODEL backend=$BACKEND"

# ---------------------------------------------------------------------------
# helpers — gpt-image-2 image_size resolver, downloads
# ---------------------------------------------------------------------------

resolve_gpt2_image_size_json() {
  # Prints a JSON value (string or {width,height}) for image_size.
  if [[ -n "$IMAGE_SIZE" ]]; then
    if [[ "$IMAGE_SIZE" == *x* ]]; then
      local w="${IMAGE_SIZE%x*}" h="${IMAGE_SIZE#*x}"
      [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] || die "invalid --image-size '$IMAGE_SIZE'"
      jq -n --argjson w "$w" --argjson h "$h" '{width:$w, height:$h}'
      return
    fi
    jq -n --arg s "$IMAGE_SIZE" '$s'
    return
  fi
  case "$ASPECT_RATIO" in
    1:1|5:4)         jq -n '"square_hd"' ;;
    16:9|21:9)       jq -n '"landscape_16_9"' ;;
    4:3|3:2|auto)    jq -n '"landscape_4_3"' ;;
    4:5|3:4|2:3)     jq -n '"portrait_4_3"' ;;
    9:16)            jq -n '"portrait_16_9"' ;;
    *)               jq -n '"landscape_4_3"' ;;
  esac
}

download_to_file() {
  local url="$1" filepath="$2"
  if [[ "$url" == data:* ]]; then
    local b64="${url#*,}"
    printf '%s' "$b64" | base64 -d > "$filepath"
  else
    curl -sSL --max-time 300 --fail -o "$filepath" "$url"
  fi
}

mkdir -p "$OUTPUT_DIR"

RESULT_FILES=()
RESULT_URLS=()
RESULT_DESC=""
RESULT_ENDPOINT=""
RESULT_BACKEND=""
RESULT_MODEL=""

# ---------------------------------------------------------------------------
# branch: fal.ai gpt-image-2 (text-to-image OR edit)
# ---------------------------------------------------------------------------

if [[ "$MODEL" == "gpt-image-2" ]]; then
  if [[ ${#IMAGE_URLS[@]} -gt 0 ]]; then
    ENDPOINT="openai/gpt-image-2/edit"
    IS_EDIT=1
  else
    ENDPOINT="openai/gpt-image-2"
    IS_EDIT=0
  fi
  RESULT_ENDPOINT="$ENDPOINT"

  REQ=$(jq -n \
    --arg prompt "$PROMPT" \
    --argjson num "$NUM_IMAGES" \
    --arg quality "$QUALITY" \
    --arg fmt "$OUTPUT_FORMAT" \
    '{prompt:$prompt, num_images:$num, quality:$quality, output_format:$fmt}')

  if [[ "$IS_EDIT" -eq 1 ]]; then
    URLS_JSON=$(printf '%s\n' "${IMAGE_URLS[@]}" | jq -R . | jq -s .)
    REQ=$(jq --argjson urls "$URLS_JSON" '. + {image_urls:$urls}' <<<"$REQ")
    if [[ -n "$MASK_URL" ]]; then
      REQ=$(jq --arg m "$MASK_URL" '. + {mask_url:$m}' <<<"$REQ")
    fi
    if [[ -n "$IMAGE_SIZE" ]]; then
      SIZE_JSON=$(resolve_gpt2_image_size_json)
      REQ=$(jq --argjson s "$SIZE_JSON" '. + {image_size:$s}' <<<"$REQ")
    fi
  else
    SIZE_JSON=$(resolve_gpt2_image_size_json)
    REQ=$(jq --argjson s "$SIZE_JSON" '. + {image_size:$s}' <<<"$REQ")
  fi

  log "[fal:$ENDPOINT] Sending request..."
  RESP=$(curl -sS --max-time 300 \
    -X POST "https://fal.run/$ENDPOINT" \
    -H "Authorization: Key $FAL_KEY" \
    -H "Content-Type: application/json" \
    -d "$REQ")

  if ! jq -e '.images' <<<"$RESP" >/dev/null 2>&1; then
    err "fal response did not include images:"
    jq -c . <<<"$RESP" >&2 2>/dev/null || err "$RESP"
    exit 1
  fi

  COUNT=$(jq '.images | length' <<<"$RESP")
  for ((i = 0; i < COUNT; i++)); do
    URL=$(jq -r ".images[$i].url" <<<"$RESP")
    SUFFIX=""
    [[ $COUNT -gt 1 ]] && SUFFIX="_$((i + 1))"
    FILEPATH="$OUTPUT_DIR/${FILENAME_PREFIX}${SUFFIX}.${OUTPUT_FORMAT}"
    download_to_file "$URL" "$FILEPATH"
    if is_remote_url "$URL"; then RESULT_URLS+=("$URL"); fi
    RESULT_FILES+=("$FILEPATH")
    log "[fal:$ENDPOINT] Saved: $FILEPATH"
  done

  RESULT_DESC=$(jq -r '.description // ""' <<<"$RESP")
  RESULT_BACKEND="fal"
  RESULT_MODEL="gpt-image-2"

# ---------------------------------------------------------------------------
# branch: OpenRouter (Gemini 3 Pro only)
# ---------------------------------------------------------------------------

elif [[ "$BACKEND" == "openrouter" ]]; then
  PROMPT_STR="$PROMPT"
  if [[ "$NUM_IMAGES" -gt 1 ]]; then
    PROMPT_STR+=" Generate $NUM_IMAGES different variations."
  fi

  IMG_CFG=$(jq -n '{}')
  if [[ -n "$ASPECT_RATIO" && "$ASPECT_RATIO" != "auto" ]]; then
    IMG_CFG=$(jq --arg a "$ASPECT_RATIO" '. + {aspect_ratio:$a}' <<<"$IMG_CFG")
  fi
  if [[ -n "$RESOLUTION" ]]; then
    IMG_CFG=$(jq --arg r "$RESOLUTION" '. + {image_size:$r}' <<<"$IMG_CFG")
  fi

  REQ=$(jq -n \
    --arg prompt "$PROMPT_STR" \
    --argjson cfg "$IMG_CFG" \
    '{
       model: "google/gemini-3-pro-image-preview",
       messages: [{role:"user", content:$prompt}],
       modalities: ["image","text"]
     } + (if ($cfg | length) > 0 then {image_config:$cfg} else {} end)')

  log "[openrouter] Sending request..."
  RESP=$(curl -sS --max-time 300 \
    -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$REQ")

  # Canonical: choices[0].message.images[].image_url.url
  # Defensive fallback: choices[0].message.content[] parts of type image_url
  IMG_URLS=$(jq -r '
    [ .choices[0].message.images // [] | .[] | .image_url.url // empty ] as $primary
    | (if ($primary | length) > 0 then $primary
       else (.choices[0].message.content // [] |
             if type == "array" then
               [ .[] | select(.type == "image_url") | .image_url.url // empty ]
             else [] end)
       end)
    | .[]
  ' <<<"$RESP")

  COUNT=0
  if [[ -n "$IMG_URLS" ]]; then
    COUNT=$(printf '%s\n' "$IMG_URLS" | wc -l | tr -d ' ')
  fi

  if [[ "$COUNT" -eq 0 ]]; then
    err "openrouter returned no images:"
    jq -c . <<<"$RESP" >&2 2>/dev/null || err "$RESP"
    exit 1
  fi

  i=0
  while IFS= read -r URL; do
    [[ -z "$URL" ]] && continue
    SUFFIX=""
    [[ $COUNT -gt 1 ]] && SUFFIX="_$((i + 1))"
    FILEPATH="$OUTPUT_DIR/${FILENAME_PREFIX}${SUFFIX}.${OUTPUT_FORMAT}"
    download_to_file "$URL" "$FILEPATH"
    if is_remote_url "$URL"; then RESULT_URLS+=("$URL"); fi
    RESULT_FILES+=("$FILEPATH")
    log "[openrouter] Saved: $FILEPATH"
    i=$((i + 1))
  done <<<"$IMG_URLS"

  RESULT_DESC=$(jq -r '
    .choices[0].message.content
    | if type == "string" then .
      elif type == "array" then [ .[] | select(.type == "text") | .text ] | join("\n")
      else "" end
  ' <<<"$RESP")
  RESULT_BACKEND="openrouter"
  RESULT_MODEL="gemini-3-pro"

# ---------------------------------------------------------------------------
# branch: fal.ai Gemini 3 Pro
# ---------------------------------------------------------------------------

elif [[ "$BACKEND" == "fal" ]]; then
  ENDPOINT="fal-ai/gemini-3-pro-image-preview"

  REQ=$(jq -n \
    --arg prompt "$PROMPT" \
    --argjson num "$NUM_IMAGES" \
    --arg ar "$ASPECT_RATIO" \
    --arg fmt "$OUTPUT_FORMAT" \
    --arg st "$SAFETY_TOLERANCE" \
    --arg res "$RESOLUTION" \
    '{prompt:$prompt, num_images:$num, aspect_ratio:$ar, output_format:$fmt, safety_tolerance:$st, resolution:$res}')

  if [[ -n "$SEED" ]]; then
    REQ=$(jq --argjson s "$SEED" '. + {seed:$s}' <<<"$REQ")
  fi

  log "[fal:$ENDPOINT] Sending request..."
  RESP=$(curl -sS --max-time 300 \
    -X POST "https://fal.run/$ENDPOINT" \
    -H "Authorization: Key $FAL_KEY" \
    -H "Content-Type: application/json" \
    -d "$REQ")

  if ! jq -e '.images' <<<"$RESP" >/dev/null 2>&1; then
    err "fal response did not include images:"
    jq -c . <<<"$RESP" >&2 2>/dev/null || err "$RESP"
    exit 1
  fi

  COUNT=$(jq '.images | length' <<<"$RESP")
  for ((i = 0; i < COUNT; i++)); do
    URL=$(jq -r ".images[$i].url" <<<"$RESP")
    SUFFIX=""
    [[ $COUNT -gt 1 ]] && SUFFIX="_$((i + 1))"
    FILEPATH="$OUTPUT_DIR/${FILENAME_PREFIX}${SUFFIX}.${OUTPUT_FORMAT}"
    download_to_file "$URL" "$FILEPATH"
    if is_remote_url "$URL"; then RESULT_URLS+=("$URL"); fi
    RESULT_FILES+=("$FILEPATH")
    log "[fal:$ENDPOINT] Saved: $FILEPATH"
  done

  RESULT_DESC=$(jq -r '.description // ""' <<<"$RESP")
  RESULT_BACKEND="fal"
  RESULT_MODEL="gemini-3-pro"
fi

# ---------------------------------------------------------------------------
# emit final JSON to stdout
# ---------------------------------------------------------------------------

files_json() {
  if [[ ${#RESULT_FILES[@]} -eq 0 ]]; then
    echo "[]"
  else
    printf '%s\n' "${RESULT_FILES[@]}" | jq -R . | jq -s .
  fi
}

urls_json() {
  if [[ ${#RESULT_URLS[@]} -eq 0 ]]; then
    echo "[]"
  else
    printf '%s\n' "${RESULT_URLS[@]}" | jq -R . | jq -s .
  fi
}

if [[ "$RESULT_BACKEND" == "fal" && "$RESULT_MODEL" == "gpt-image-2" ]]; then
  jq -n \
    --argjson files "$(files_json)" \
    --argjson urls  "$(urls_json)" \
    --arg endpoint "$RESULT_ENDPOINT" \
    --arg desc     "$RESULT_DESC" \
    '{backend:"fal", model:"gpt-image-2", endpoint:$endpoint, files:$files, urls:$urls, description:$desc}'
else
  jq -n \
    --argjson files "$(files_json)" \
    --argjson urls  "$(urls_json)" \
    --arg backend "$RESULT_BACKEND" \
    --arg model   "$RESULT_MODEL" \
    --arg desc    "$RESULT_DESC" \
    '{backend:$backend, model:$model, files:$files, urls:$urls, description:$desc}'
fi
