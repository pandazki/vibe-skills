#!/usr/bin/env python3
"""Generate images via fal.ai or OpenRouter.

Supported models:
  - gpt-image-2   : OpenAI GPT-Image-2 via fal.ai (default; text-to-image and edit)
  - gemini-3-pro  : Gemini 3 Pro Image Preview (fal.ai or OpenRouter)
"""

import argparse
import base64
import json
import os
import sys
import urllib.request
import urllib.error


def find_env_file():
    """Search for .env file: skill root first, then cwd upward."""
    # 1. Check skill root directory (parent of scripts/)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    skill_root = os.path.dirname(script_dir)
    skill_env = os.path.join(skill_root, ".env")
    if os.path.isfile(skill_env):
        return skill_env

    # 2. Fallback: search from cwd upward
    path = os.getcwd()
    while True:
        env_path = os.path.join(path, ".env")
        if os.path.isfile(env_path):
            return env_path
        parent = os.path.dirname(path)
        if parent == path:
            return None
        path = parent


def load_env_keys() -> dict[str, str]:
    """Load API keys from .env file. Returns dict of found keys."""
    keys = {}

    # Check environment variables first
    for var in ("FAL_KEY", "OPENROUTER_API_KEY"):
        if os.environ.get(var):
            keys[var] = os.environ[var]

    env_path = find_env_file()
    if not env_path:
        return keys

    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, _, value = line.partition("=")
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                if key in ("FAL_KEY", "OPENROUTER_API_KEY") and value:
                    keys[key] = value

    return keys


def detect_backend(keys: dict[str, str]) -> str:
    """Auto-detect backend based on available keys. Prefer fal.ai."""
    if "FAL_KEY" in keys:
        return "fal"
    if "OPENROUTER_API_KEY" in keys:
        return "openrouter"
    return "none"


# Aspect-ratio → fal.ai image_size preset for GPT-Image-2.
# Falls back to `landscape_4_3` for unknown ratios.
_GPT2_ASPECT_TO_SIZE = {
    "1:1": "square_hd",
    "16:9": "landscape_16_9",
    "4:3": "landscape_4_3",
    "3:2": "landscape_4_3",
    "5:4": "square_hd",
    "4:5": "portrait_4_3",
    "3:4": "portrait_4_3",
    "2:3": "portrait_4_3",
    "9:16": "portrait_16_9",
    "21:9": "landscape_16_9",
    "auto": "landscape_4_3",
}


def _resolve_gpt2_image_size(image_size: str | None, aspect_ratio: str):
    """Resolve GPT-Image-2 image_size param.

    Accepts:
      - preset name string (e.g. 'landscape_4_3') — passed through
      - explicit 'WxH' (e.g. '1024x1024') — converted to {width, height}
      - None — derived from --aspect-ratio
    """
    if image_size:
        if "x" in image_size.lower():
            try:
                w, h = image_size.lower().split("x", 1)
                return {"width": int(w), "height": int(h)}
            except ValueError:
                print(f"ERROR: invalid --image-size '{image_size}', expected WxH or preset name", file=sys.stderr)
                sys.exit(1)
        return image_size
    return _GPT2_ASPECT_TO_SIZE.get(aspect_ratio, "landscape_4_3")


# ---------------------------------------------------------------------------
# OpenRouter backend (Gemini 3 Pro only; stdlib, no extra deps)
# ---------------------------------------------------------------------------

def generate_via_openrouter(
    api_key: str,
    prompt: str,
    num_images: int = 1,
    aspect_ratio: str = "1:1",
    resolution: str = "1K",
    output_format: str = "png",
    output_dir: str = ".",
    filename_prefix: str = "illustration",
    **_kwargs,
) -> dict:
    """Generate images via OpenRouter Chat Completions API (Gemini 3 Pro)."""

    image_instruction = ""
    if num_images > 1:
        image_instruction = f" Generate {num_images} different variations."

    messages = [
        {
            "role": "user",
            "content": f"{prompt}{image_instruction}",
        }
    ]

    # image_config: aspect_ratio + image_size (1K/2K/4K)
    image_config = {}
    if aspect_ratio and aspect_ratio != "auto":
        image_config["aspect_ratio"] = aspect_ratio
    if resolution:
        image_config["image_size"] = resolution

    body = {
        "model": "google/gemini-3-pro-image-preview",
        "messages": messages,
        "modalities": ["image", "text"],
    }
    if image_config:
        body["image_config"] = image_config

    payload = json.dumps(body).encode()

    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )

    print("[openrouter] Sending request...", file=sys.stderr)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode() if e.fp else ""
        print(f"ERROR: OpenRouter API returned {e.code}: {body}", file=sys.stderr)
        sys.exit(1)

    # Extract images from response
    os.makedirs(output_dir, exist_ok=True)
    saved_files = []
    urls = []

    message = result.get("choices", [{}])[0].get("message", {})

    # OpenRouter returns images in parts (multimodal content) or in message.images
    images_data = []

    # Format 1: message.images[]
    if message.get("images"):
        for img in message["images"]:
            url = img.get("image_url", {}).get("url", "")
            if url:
                images_data.append(url)

    # Format 2: message.content as array with image parts
    elif isinstance(message.get("content"), list):
        for part in message["content"]:
            if part.get("type") == "image_url":
                url = part.get("image_url", {}).get("url", "")
                if url:
                    images_data.append(url)

    for i, image_url in enumerate(images_data):
        suffix = f"_{i+1}" if len(images_data) > 1 else ""
        filename = f"{filename_prefix}{suffix}.{output_format}"
        filepath = os.path.join(output_dir, filename)

        if image_url.startswith("data:"):
            # base64 data URL: data:image/png;base64,xxxxx
            header, _, b64data = image_url.partition(",")
            img_bytes = base64.b64decode(b64data)
            with open(filepath, "wb") as f:
                f.write(img_bytes)
        else:
            # Remote URL
            urllib.request.urlretrieve(image_url, filepath)
            urls.append(image_url)

        saved_files.append(filepath)
        print(f"[openrouter] Saved: {filepath}", file=sys.stderr)

    # Extract text description if present
    description = ""
    if isinstance(message.get("content"), str):
        description = message["content"]
    elif isinstance(message.get("content"), list):
        text_parts = [p.get("text", "") for p in message["content"] if p.get("type") == "text"]
        description = "\n".join(text_parts)

    return {
        "backend": "openrouter",
        "model": "gemini-3-pro",
        "files": saved_files,
        "urls": urls,
        "description": description,
    }


# ---------------------------------------------------------------------------
# fal.ai backend — Gemini 3 Pro (requires fal-client)
# ---------------------------------------------------------------------------

def _import_fal_client():
    try:
        import fal_client
        return fal_client
    except ImportError:
        print("ERROR: fal-client not installed. Run: cd <skill_dir> && uv venv && uv pip install fal-client", file=sys.stderr)
        sys.exit(1)


def _download_fal_images(result: dict, output_format: str, num_images: int,
                        output_dir: str, filename_prefix: str, backend_tag: str):
    os.makedirs(output_dir, exist_ok=True)
    saved_files = []
    urls = []
    for i, img in enumerate(result.get("images", [])):
        url = img["url"]
        urls.append(url)
        suffix = f"_{i+1}" if num_images > 1 else ""
        filename = f"{filename_prefix}{suffix}.{output_format}"
        filepath = os.path.join(output_dir, filename)
        urllib.request.urlretrieve(url, filepath)
        saved_files.append(filepath)
        print(f"[{backend_tag}] Saved: {filepath}", file=sys.stderr)
    return saved_files, urls


def generate_via_fal_gemini(
    api_key: str,
    prompt: str,
    num_images: int = 1,
    aspect_ratio: str = "1:1",
    output_format: str = "png",
    safety_tolerance: str = "4",
    resolution: str = "1K",
    seed: int | None = None,
    output_dir: str = ".",
    filename_prefix: str = "illustration",
    **_kwargs,
) -> dict:
    """Generate images via fal.ai Gemini 3 Pro Image Preview."""
    fal_client = _import_fal_client()
    os.environ["FAL_KEY"] = api_key

    arguments = {
        "prompt": prompt,
        "num_images": num_images,
        "aspect_ratio": aspect_ratio,
        "output_format": output_format,
        "safety_tolerance": safety_tolerance,
        "resolution": resolution,
    }
    if seed is not None:
        arguments["seed"] = seed

    def on_queue_update(update):
        if isinstance(update, fal_client.InProgress):
            for log in update.logs:
                print(f"  [log] {log['message']}", file=sys.stderr)

    print("[fal:gemini-3-pro] Sending request...", file=sys.stderr)
    result = fal_client.subscribe(
        "fal-ai/gemini-3-pro-image-preview",
        arguments=arguments,
        with_logs=True,
        on_queue_update=on_queue_update,
    )

    saved_files, urls = _download_fal_images(
        result, output_format, num_images, output_dir, filename_prefix, "fal:gemini-3-pro"
    )

    return {
        "backend": "fal",
        "model": "gemini-3-pro",
        "files": saved_files,
        "urls": urls,
        "description": result.get("description", ""),
    }


# ---------------------------------------------------------------------------
# fal.ai backend — OpenAI GPT-Image-2 (text-to-image and edit)
# ---------------------------------------------------------------------------

def generate_via_fal_gpt_image_2(
    api_key: str,
    prompt: str,
    num_images: int = 1,
    aspect_ratio: str = "1:1",
    image_size: str | None = None,
    quality: str = "high",
    output_format: str = "png",
    image_urls: list[str] | None = None,
    mask_url: str | None = None,
    output_dir: str = ".",
    filename_prefix: str = "illustration",
    **_kwargs,
) -> dict:
    """Generate images via fal.ai openai/gpt-image-2 (text-to-image or edit)."""
    fal_client = _import_fal_client()
    os.environ["FAL_KEY"] = api_key

    is_edit = bool(image_urls)
    endpoint = "openai/gpt-image-2/edit" if is_edit else "openai/gpt-image-2"

    arguments = {
        "prompt": prompt,
        "num_images": num_images,
        "quality": quality,
        "output_format": output_format,
    }

    if is_edit:
        arguments["image_urls"] = image_urls
        if mask_url:
            arguments["mask_url"] = mask_url
        # Edit endpoint defaults image_size to 'auto' — only set when user opts in
        if image_size:
            arguments["image_size"] = _resolve_gpt2_image_size(image_size, aspect_ratio)
    else:
        arguments["image_size"] = _resolve_gpt2_image_size(image_size, aspect_ratio)

    def on_queue_update(update):
        if isinstance(update, fal_client.InProgress):
            for log in update.logs:
                print(f"  [log] {log['message']}", file=sys.stderr)

    tag = "fal:gpt-image-2/edit" if is_edit else "fal:gpt-image-2"
    print(f"[{tag}] Sending request...", file=sys.stderr)
    result = fal_client.subscribe(
        endpoint,
        arguments=arguments,
        with_logs=True,
        on_queue_update=on_queue_update,
    )

    saved_files, urls = _download_fal_images(
        result, output_format, num_images, output_dir, filename_prefix, tag
    )

    return {
        "backend": "fal",
        "model": "gpt-image-2",
        "endpoint": endpoint,
        "files": saved_files,
        "urls": urls,
        "description": result.get("description", ""),
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Generate images (GPT-Image-2 default, or Gemini 3 Pro; auto-routes between fal.ai and OpenRouter)"
    )
    parser.add_argument("prompt", help="Text prompt for image generation")
    parser.add_argument("--model", default="gpt-image-2",
                        choices=["gemini-3-pro", "gpt-image-2"],
                        help="Which image model to use (default: gpt-image-2)")
    parser.add_argument("--num-images", type=int, default=1, choices=[1, 2, 3, 4])
    parser.add_argument("--aspect-ratio", default="1:1",
                        choices=["auto", "21:9", "16:9", "3:2", "4:3", "5:4", "1:1", "4:5", "3:4", "2:3", "9:16"],
                        help="Used by gemini-3-pro directly; mapped to a preset for gpt-image-2")
    parser.add_argument("--output-format", default="png", choices=["jpeg", "png", "webp"])
    # Gemini-only
    parser.add_argument("--resolution", default="1K", choices=["1K", "2K", "4K"],
                        help="Gemini 3 Pro only")
    parser.add_argument("--safety-tolerance", default="4", choices=["1", "2", "3", "4", "5", "6"],
                        help="Gemini 3 Pro (fal.ai) only")
    parser.add_argument("--seed", type=int, default=None,
                        help="Gemini 3 Pro (fal.ai) only")
    # GPT-Image-2 only
    parser.add_argument("--quality", default="high", choices=["low", "medium", "high"],
                        help="GPT-Image-2 only (affects cost)")
    parser.add_argument("--image-size", default=None,
                        help="GPT-Image-2 only. Preset name (e.g. landscape_4_3) or WxH (e.g. 1024x1024). Overrides --aspect-ratio mapping.")
    parser.add_argument("--image-urls", nargs="+", default=None,
                        help="GPT-Image-2 edit endpoint: one or more reference image URLs")
    parser.add_argument("--mask-url", default=None,
                        help="GPT-Image-2 edit endpoint: optional mask URL")

    parser.add_argument("--output-dir", default=".")
    parser.add_argument("--filename-prefix", default="illustration")
    parser.add_argument("--backend", default=None, choices=["fal", "openrouter"],
                        help="Force a specific backend (default: auto-detect from .env keys)")
    args = parser.parse_args()

    keys = load_env_keys()
    backend = args.backend or detect_backend(keys)

    # GPT-Image-2 is only available via fal.ai.
    if args.model == "gpt-image-2":
        if backend == "openrouter":
            if "FAL_KEY" not in keys:
                print("ERROR: --model gpt-image-2 requires FAL_KEY (not available on OpenRouter).", file=sys.stderr)
                sys.exit(1)
            print("[router] Note: gpt-image-2 is fal.ai-only — switching backend to fal.", file=sys.stderr)
            backend = "fal"
        elif backend == "none":
            print("ERROR: --model gpt-image-2 requires FAL_KEY in .env. Get one at https://fal.ai/dashboard/keys", file=sys.stderr)
            sys.exit(1)

    if backend == "none":
        print("ERROR: No API key found in .env file.", file=sys.stderr)
        print("Please add one of the following to the .env file in the skill directory:", file=sys.stderr)
        print("  OPENROUTER_API_KEY=your_openrouter_key   (https://openrouter.ai/keys)", file=sys.stderr)
        print("  FAL_KEY=your_fal_key                     (https://fal.ai/dashboard/keys)", file=sys.stderr)
        sys.exit(1)

    print(f"[router] model={args.model} backend={backend}", file=sys.stderr)

    if args.model == "gpt-image-2":
        result = generate_via_fal_gpt_image_2(
            api_key=keys["FAL_KEY"],
            prompt=args.prompt,
            num_images=args.num_images,
            aspect_ratio=args.aspect_ratio,
            image_size=args.image_size,
            quality=args.quality,
            output_format=args.output_format,
            image_urls=args.image_urls,
            mask_url=args.mask_url,
            output_dir=args.output_dir,
            filename_prefix=args.filename_prefix,
        )
    elif backend == "openrouter":
        result = generate_via_openrouter(
            api_key=keys["OPENROUTER_API_KEY"],
            prompt=args.prompt,
            num_images=args.num_images,
            aspect_ratio=args.aspect_ratio,
            resolution=args.resolution,
            output_format=args.output_format,
            output_dir=args.output_dir,
            filename_prefix=args.filename_prefix,
        )
    elif backend == "fal":
        result = generate_via_fal_gemini(
            api_key=keys["FAL_KEY"],
            prompt=args.prompt,
            num_images=args.num_images,
            aspect_ratio=args.aspect_ratio,
            output_format=args.output_format,
            resolution=args.resolution,
            safety_tolerance=args.safety_tolerance,
            seed=args.seed,
            output_dir=args.output_dir,
            filename_prefix=args.filename_prefix,
        )
    else:
        print(f"ERROR: Unknown backend '{backend}'", file=sys.stderr)
        sys.exit(1)

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
