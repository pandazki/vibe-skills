#!/usr/bin/env node
// Generate images via fal.ai or OpenRouter.
// Same flags + JSON output as scripts/generate_image.py.
// Runs on Node >= 18 (global fetch) and Bun. Zero npm deps.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { argv, cwd, env, exit, stderr, stdout } from 'node:process';
import { Buffer } from 'node:buffer';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ---------------------------------------------------------------------------
// .env loading (skill root first, then walk up from cwd)
// ---------------------------------------------------------------------------

function findEnvFile() {
  const skillRoot = dirname(__dirname);
  const skillEnv = join(skillRoot, '.env');
  if (existsSync(skillEnv)) return skillEnv;

  let p = cwd();
  while (true) {
    const candidate = join(p, '.env');
    if (existsSync(candidate)) return candidate;
    const parent = dirname(p);
    if (parent === p) return null;
    p = parent;
  }
}

function loadEnvKeys() {
  const keys = {};
  for (const k of ['FAL_KEY', 'OPENROUTER_API_KEY']) {
    if (env[k]) keys[k] = env[k];
  }
  const envPath = findEnvFile();
  if (!envPath) return keys;
  const text = readFileSync(envPath, 'utf8');
  for (let line of text.split(/\r?\n/)) {
    line = line.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq < 0) continue;
    const k = line.slice(0, eq).trim();
    let v = line.slice(eq + 1).trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
      v = v.slice(1, -1);
    }
    if ((k === 'FAL_KEY' || k === 'OPENROUTER_API_KEY') && v) keys[k] = v;
  }
  return keys;
}

function detectBackend(keys) {
  if (keys.FAL_KEY) return 'fal';
  if (keys.OPENROUTER_API_KEY) return 'openrouter';
  return 'none';
}

// ---------------------------------------------------------------------------
// argv parsing
// ---------------------------------------------------------------------------

function die(msg) {
  stderr.write(`ERROR: ${msg}\n`);
  exit(1);
}

function printHelp() {
  stderr.write(`Usage: generate_image.mjs <prompt> [flags]

Same flags as scripts/generate_image.py:
  --model {gemini-3-pro|gpt-image-2}    default gpt-image-2
  --num-images {1|2|3|4}                default 1
  --aspect-ratio {auto|21:9|16:9|3:2|4:3|5:4|1:1|4:5|3:4|2:3|9:16}
  --output-format {jpeg|png|webp}        default png
  --resolution {1K|2K|4K}                Gemini only, default 1K
  --safety-tolerance {1..6}              Gemini fal only, default 4
  --seed <int>                           Gemini fal only
  --quality {low|medium|high}            GPT-Image-2 only, default high
  --image-size <preset|WxH>              GPT-Image-2 only
  --image-urls <url> [<url> ...]         GPT-Image-2 edit
  --mask-url <url>                       GPT-Image-2 edit
  --output-dir <path>                    default .
  --filename-prefix <name>               default illustration
  --backend {fal|openrouter}             default auto-detect from .env

Run with:  node scripts/generate_image.mjs <args>   (Node >= 18)
       or  bun  scripts/generate_image.mjs <args>
`);
}

const ENUMS = {
  model: ['gemini-3-pro', 'gpt-image-2'],
  numImages: [1, 2, 3, 4],
  aspectRatio: ['auto', '21:9', '16:9', '3:2', '4:3', '5:4', '1:1', '4:5', '3:4', '2:3', '9:16'],
  outputFormat: ['jpeg', 'png', 'webp'],
  resolution: ['1K', '2K', '4K'],
  safetyTolerance: ['1', '2', '3', '4', '5', '6'],
  quality: ['low', 'medium', 'high'],
  backend: ['fal', 'openrouter'],
};

function parseArgs(args) {
  const out = {
    prompt: null,
    model: 'gpt-image-2',
    numImages: 1,
    aspectRatio: '1:1',
    outputFormat: 'png',
    resolution: '1K',
    safetyTolerance: '4',
    seed: null,
    quality: 'high',
    imageSize: null,
    imageUrls: null,
    maskUrl: null,
    outputDir: '.',
    filenamePrefix: 'illustration',
    backend: null,
  };

  const requireEnum = (name, val, list) => {
    if (!list.includes(val)) die(`--${name} must be one of: ${list.join(', ')}`);
  };

  let i = 0;
  while (i < args.length) {
    const a = args[i];
    if (a === '-h' || a === '--help') {
      printHelp();
      exit(0);
    } else if (!a.startsWith('-')) {
      if (out.prompt === null) out.prompt = a;
      else die(`unexpected positional argument: ${a}`);
      i++;
    } else if (a === '--model') {
      out.model = args[++i]; requireEnum('model', out.model, ENUMS.model); i++;
    } else if (a === '--num-images') {
      out.numImages = parseInt(args[++i], 10);
      if (!ENUMS.numImages.includes(out.numImages)) die('--num-images must be 1-4');
      i++;
    } else if (a === '--aspect-ratio') {
      out.aspectRatio = args[++i]; requireEnum('aspect-ratio', out.aspectRatio, ENUMS.aspectRatio); i++;
    } else if (a === '--output-format') {
      out.outputFormat = args[++i]; requireEnum('output-format', out.outputFormat, ENUMS.outputFormat); i++;
    } else if (a === '--resolution') {
      out.resolution = args[++i]; requireEnum('resolution', out.resolution, ENUMS.resolution); i++;
    } else if (a === '--safety-tolerance') {
      out.safetyTolerance = args[++i]; requireEnum('safety-tolerance', out.safetyTolerance, ENUMS.safetyTolerance); i++;
    } else if (a === '--seed') {
      out.seed = parseInt(args[++i], 10);
      if (Number.isNaN(out.seed)) die('--seed must be an integer');
      i++;
    } else if (a === '--quality') {
      out.quality = args[++i]; requireEnum('quality', out.quality, ENUMS.quality); i++;
    } else if (a === '--image-size') {
      out.imageSize = args[++i]; i++;
    } else if (a === '--image-urls') {
      out.imageUrls = [];
      i++;
      while (i < args.length && !args[i].startsWith('-')) {
        out.imageUrls.push(args[i++]);
      }
    } else if (a === '--mask-url') {
      out.maskUrl = args[++i]; i++;
    } else if (a === '--output-dir') {
      out.outputDir = args[++i]; i++;
    } else if (a === '--filename-prefix') {
      out.filenamePrefix = args[++i]; i++;
    } else if (a === '--backend') {
      out.backend = args[++i]; requireEnum('backend', out.backend, ENUMS.backend); i++;
    } else {
      die(`unknown flag: ${a}`);
    }
  }

  if (out.prompt === null) {
    printHelp();
    die('prompt is required');
  }
  return out;
}

// ---------------------------------------------------------------------------
// shared helpers
// ---------------------------------------------------------------------------

const GPT2_ASPECT_TO_SIZE = {
  '1:1': 'square_hd',
  '16:9': 'landscape_16_9',
  '4:3': 'landscape_4_3',
  '3:2': 'landscape_4_3',
  '5:4': 'square_hd',
  '4:5': 'portrait_4_3',
  '3:4': 'portrait_4_3',
  '2:3': 'portrait_4_3',
  '9:16': 'portrait_16_9',
  '21:9': 'landscape_16_9',
  'auto': 'landscape_4_3',
};

function resolveGpt2ImageSize(imageSize, aspectRatio) {
  if (imageSize) {
    if (imageSize.toLowerCase().includes('x')) {
      const [w, h] = imageSize.toLowerCase().split('x', 2);
      const wn = parseInt(w, 10);
      const hn = parseInt(h, 10);
      if (Number.isNaN(wn) || Number.isNaN(hn)) {
        die(`invalid --image-size '${imageSize}', expected WxH or preset name`);
      }
      return { width: wn, height: hn };
    }
    return imageSize;
  }
  return GPT2_ASPECT_TO_SIZE[aspectRatio] || 'landscape_4_3';
}

function ensureDir(d) {
  if (!existsSync(d)) mkdirSync(d, { recursive: true });
}

async function downloadOrDecode(url, filepath) {
  if (url.startsWith('data:')) {
    const comma = url.indexOf(',');
    if (comma < 0) throw new Error('malformed data URL');
    const b64 = url.slice(comma + 1);
    writeFileSync(filepath, Buffer.from(b64, 'base64'));
    return false; // not a remote URL
  }
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`download ${url} -> HTTP ${resp.status}`);
  writeFileSync(filepath, Buffer.from(await resp.arrayBuffer()));
  return true;
}

// ---------------------------------------------------------------------------
// fal.ai — sync mode (one POST, final JSON back)
// ---------------------------------------------------------------------------

async function callFalSync(endpoint, apiKey, body) {
  const url = `https://fal.run/${endpoint}`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Key ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!resp.ok) {
    const text = await resp.text();
    die(`fal.ai returned HTTP ${resp.status}: ${text.slice(0, 800)}`);
  }
  return await resp.json();
}

async function generateViaFalGpt2(opts, apiKey) {
  const isEdit = Array.isArray(opts.imageUrls) && opts.imageUrls.length > 0;
  const endpoint = isEdit ? 'openai/gpt-image-2/edit' : 'openai/gpt-image-2';

  const body = {
    prompt: opts.prompt,
    num_images: opts.numImages,
    quality: opts.quality,
    output_format: opts.outputFormat,
  };

  if (isEdit) {
    body.image_urls = opts.imageUrls;
    if (opts.maskUrl) body.mask_url = opts.maskUrl;
    if (opts.imageSize) body.image_size = resolveGpt2ImageSize(opts.imageSize, opts.aspectRatio);
  } else {
    body.image_size = resolveGpt2ImageSize(opts.imageSize, opts.aspectRatio);
  }

  const tag = `fal:${endpoint}`;
  stderr.write(`[${tag}] Sending request...\n`);
  const result = await callFalSync(endpoint, apiKey, body);

  ensureDir(opts.outputDir);
  const files = [];
  const urls = [];
  const images = result.images ?? [];
  for (let i = 0; i < images.length; i++) {
    const u = images[i].url;
    const suffix = images.length > 1 ? `_${i + 1}` : '';
    const filename = `${opts.filenamePrefix}${suffix}.${opts.outputFormat}`;
    const filepath = join(opts.outputDir, filename);
    const wasRemote = await downloadOrDecode(u, filepath);
    if (wasRemote) urls.push(u);
    files.push(filepath);
    stderr.write(`[${tag}] Saved: ${filepath}\n`);
  }

  return {
    backend: 'fal',
    model: 'gpt-image-2',
    endpoint,
    files,
    urls,
    description: result.description ?? '',
  };
}

async function generateViaFalGemini(opts, apiKey) {
  const endpoint = 'fal-ai/gemini-3-pro-image-preview';
  const body = {
    prompt: opts.prompt,
    num_images: opts.numImages,
    aspect_ratio: opts.aspectRatio,
    output_format: opts.outputFormat,
    safety_tolerance: opts.safetyTolerance,
    resolution: opts.resolution,
  };
  if (opts.seed !== null) body.seed = opts.seed;

  const tag = `fal:${endpoint}`;
  stderr.write(`[${tag}] Sending request...\n`);
  const result = await callFalSync(endpoint, apiKey, body);

  ensureDir(opts.outputDir);
  const files = [];
  const urls = [];
  const images = result.images ?? [];
  for (let i = 0; i < images.length; i++) {
    const u = images[i].url;
    const suffix = images.length > 1 ? `_${i + 1}` : '';
    const filename = `${opts.filenamePrefix}${suffix}.${opts.outputFormat}`;
    const filepath = join(opts.outputDir, filename);
    const wasRemote = await downloadOrDecode(u, filepath);
    if (wasRemote) urls.push(u);
    files.push(filepath);
    stderr.write(`[${tag}] Saved: ${filepath}\n`);
  }

  return {
    backend: 'fal',
    model: 'gemini-3-pro',
    files,
    urls,
    description: result.description ?? '',
  };
}

// ---------------------------------------------------------------------------
// OpenRouter (Gemini 3 Pro only)
// ---------------------------------------------------------------------------

async function generateViaOpenRouter(opts, apiKey) {
  const url = 'https://openrouter.ai/api/v1/chat/completions';
  let promptStr = opts.prompt;
  if (opts.numImages > 1) promptStr += ` Generate ${opts.numImages} different variations.`;

  const imageConfig = {};
  if (opts.aspectRatio && opts.aspectRatio !== 'auto') imageConfig.aspect_ratio = opts.aspectRatio;
  if (opts.resolution) imageConfig.image_size = opts.resolution;

  const body = {
    model: 'google/gemini-3-pro-image-preview',
    messages: [{ role: 'user', content: promptStr }],
    modalities: ['image', 'text'],
  };
  if (Object.keys(imageConfig).length) body.image_config = imageConfig;

  stderr.write(`[openrouter] Sending request...\n`);
  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!resp.ok) {
    const text = await resp.text();
    die(`OpenRouter HTTP ${resp.status}: ${text.slice(0, 800)}`);
  }
  const result = await resp.json();
  const message = result.choices?.[0]?.message ?? {};

  // Canonical: message.images[].image_url.url. Defensive fallback: content array parts.
  const imageUrls = [];
  if (Array.isArray(message.images)) {
    for (const im of message.images) {
      const u = im?.image_url?.url;
      if (u) imageUrls.push(u);
    }
  }
  if (imageUrls.length === 0 && Array.isArray(message.content)) {
    for (const part of message.content) {
      if (part?.type === 'image_url' && part?.image_url?.url) imageUrls.push(part.image_url.url);
    }
  }

  ensureDir(opts.outputDir);
  const files = [];
  const urls = [];
  for (let i = 0; i < imageUrls.length; i++) {
    const u = imageUrls[i];
    const suffix = imageUrls.length > 1 ? `_${i + 1}` : '';
    const filename = `${opts.filenamePrefix}${suffix}.${opts.outputFormat}`;
    const filepath = join(opts.outputDir, filename);
    const wasRemote = await downloadOrDecode(u, filepath);
    if (wasRemote) urls.push(u);
    files.push(filepath);
    stderr.write(`[openrouter] Saved: ${filepath}\n`);
  }

  let description = '';
  if (typeof message.content === 'string') description = message.content;
  else if (Array.isArray(message.content)) {
    description = message.content
      .filter((p) => p?.type === 'text')
      .map((p) => p?.text ?? '')
      .join('\n');
  }

  return {
    backend: 'openrouter',
    model: 'gemini-3-pro',
    files,
    urls,
    description,
  };
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

async function main() {
  const opts = parseArgs(argv.slice(2));
  const keys = loadEnvKeys();
  let backend = opts.backend ?? detectBackend(keys);

  if (opts.model === 'gpt-image-2') {
    if (backend === 'openrouter') {
      if (!keys.FAL_KEY) die('--model gpt-image-2 requires FAL_KEY (not available on OpenRouter).');
      stderr.write('[router] Note: gpt-image-2 is fal.ai-only — switching backend to fal.\n');
      backend = 'fal';
    } else if (backend === 'none') {
      die('--model gpt-image-2 requires FAL_KEY in .env. Get one at https://fal.ai/dashboard/keys');
    }
  }

  if (backend === 'none') {
    stderr.write('ERROR: No API key found in .env file.\n');
    stderr.write('Please add one of the following to the .env file in the skill directory:\n');
    stderr.write('  OPENROUTER_API_KEY=your_openrouter_key   (https://openrouter.ai/keys)\n');
    stderr.write('  FAL_KEY=your_fal_key                     (https://fal.ai/dashboard/keys)\n');
    exit(1);
  }

  stderr.write(`[router] model=${opts.model} backend=${backend}\n`);

  let result;
  if (opts.model === 'gpt-image-2') {
    result = await generateViaFalGpt2(opts, keys.FAL_KEY);
  } else if (backend === 'openrouter') {
    result = await generateViaOpenRouter(opts, keys.OPENROUTER_API_KEY);
  } else if (backend === 'fal') {
    result = await generateViaFalGemini(opts, keys.FAL_KEY);
  } else {
    die(`Unknown backend '${backend}'`);
  }

  stdout.write(JSON.stringify(result, null, 2) + '\n');
}

main().catch((err) => {
  stderr.write(`ERROR: ${err.message ?? err}\n`);
  exit(1);
});
