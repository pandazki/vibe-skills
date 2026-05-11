# Jina Reader — Complete Headers Reference

## Table of contents
- [Authentication](#authentication)
- [Response format](#response-format)
- [Content extraction](#content-extraction)
- [Browser & rendering](#browser--rendering)
- [Caching](#caching)
- [Network](#network)
- [Markdown formatting (Turndown)](#markdown-formatting-turndown)

## Authentication

| Header | Type | Description |
|--------|------|-------------|
| `Authorization` | `Bearer <key>` | Jina API key. Increases rate limit from 20 RPM to 500+ RPM |

## Response format

| Header | Values | Description |
|--------|--------|-------------|
| `Accept` | `application/json` | JSON: `{url, title, content, timestamp}`. For `s.jina.ai`: list of 5 results |
| `Accept` | `text/event-stream` | Streaming. Each chunk more complete; last chunk is final |
| `X-Return-Format` | `markdown` | Default. Clean markdown after readability filtering |
| `X-Return-Format` | `html` | Raw `documentElement.outerHTML` |
| `X-Return-Format` | `text` | Plain `document.body.innerText` |
| `X-Return-Format` | `screenshot` | Returns URL of a webpage screenshot |

## Content extraction

| Header | Type | Description |
|--------|------|-------------|
| `X-Target-Selector` | CSS selector | Extract only matched elements. Example: `article, .main-content` |
| `X-Wait-For-Selector` | CSS selector | Wait until element appears before extracting |
| `X-Remove-Selector` | CSS selector | Remove matched elements. Example: `nav, footer, .sidebar` |
| `X-With-Generated-Alt` | `true`/`false` | Caption images via VLM, add as alt tags. Default: false |
| `X-With-Images` | `true`/`false` | Include/strip images |
| `X-With-Links-Summary` | `all`/`none` | Append "Buttons & Links" section |
| `X-With-Images-Summary` | `all`/`none` | Append "Images" section |
| `X-Token-Budget` | integer | Max tokens for response. Request fails if exceeded |
| `X-Use-Reader-LM-V2` | `true` | ReaderLM-v2 (1.5B) for HTML→MD. Higher quality, 3x cost |
| `X-Openai-Citation-Format` | `true` | OpenAI web browsing citation markers |
| `X-With-Iframe` | `true` | Extract content from iframes |
| `X-With-Shadow-Dom` | `true` | Extract from Shadow DOM |

## Browser & rendering

| Header | Type | Description |
|--------|------|-------------|
| `X-Timeout` | integer (s) | Max wait for page load. Forces wait for network idle |
| `X-Locale` | locale string | Browser locale (e.g. `zh-CN`). Affects served content |
| `X-Set-Cookie` | cookie string | Forward cookies. Format: `name=value; domain=example.com`. Bypasses cache |
| `X-Proxy-Url` | URL | Route through proxy |
| `X-Proxy-Country` | code | Country-specific proxy. `auto` for optimal |
| `X-User-Agent` | UA string | Override User-Agent |
| `X-Referer` | URL | Set HTTP Referer |
| `X-Viewport-Width` | pixels | Browser width (POST only) |
| `X-Viewport-Height` | pixels | Browser height (POST only) |
| `X-Robots-Respect` | bot name | Check robots.txt using specified bot name |
| `X-Js-Code` | JS code/URL | Execute JS before extraction (POST only) |
| `X-Wait-For` | timing | `domcontentloaded`/`load`/`networkidle0`/`networkidle2` |

## Caching

| Header | Type | Description |
|--------|------|-------------|
| `X-No-Cache` | `true` | Bypass cache entirely (= `X-Cache-Tolerance: 0`) |
| `X-Cache-Tolerance` | integer (s) | Accept cached if younger than N seconds. Default: 3600 |
| `X-No-Track` | `true` | Don't cache or log this request |

## Network

| Header | Type | Description |
|--------|------|-------------|
| `X-Base64-Preserve` | `true` | Keep inline base64 images in markdown |
| `X-Use-Final-Url` | `true` | Resolve relative URLs from final URL after redirects |

## Markdown formatting (Turndown)

| Header | Values | Default | Description |
|--------|--------|---------|-------------|
| `X-Md-Heading-Style` | `setext`/`atx` | `atx` | Heading format |
| `X-Md-Hr` | `***`/`---`/`___` | `***` | Horizontal rule |
| `X-Md-Bullet-List-Marker` | `*`/`-`/`+` | `*` | Bullet character |
| `X-Md-Emphasis-Delimiter` | `_`/`*` | `_` | Italic delimiter |
| `X-Md-Strong-Delimiter` | `**`/`__` | `**` | Bold delimiter |
| `X-Md-Link-Style` | `inlined`/`referenced` | `inlined` | Link format |
| `X-Gfm` | `true`/`false` | `true` | GitHub Flavored Markdown |
