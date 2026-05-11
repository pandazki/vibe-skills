# vibe-skills

A curated collection of Claude Code skills for vibe coding workflows.

For more information about skills, check out:
- [What are skills?](https://support.claude.com/en/articles/12512176-what-are-skills)
- [Using skills in Claude](https://support.claude.com/en/articles/12512180-using-skills-in-claude)
- [How to create custom skills](https://support.claude.com/en/articles/12512198-creating-custom-skills)

## Skills

| Skill | Description |
|---|---|
| [contextual-illustrator](./contextual-illustrator) | Context-aware image generation using Gemini 3 Pro Image, with OpenRouter / fal.ai dual-backend |
| [web-explorer](./web-explorer) | Read, search, and research web content — fetch URLs, search the web, or run deep multi-step research |

## Install in Claude Code

Register this repository as a Plugin marketplace:

```
/plugin marketplace add pandazki/vibe-skills
```

Then install a skill:

1. Select `Browse and install plugins`
2. Select `vibe-skills`
3. Select `contextual-illustrator`
4. Select `Install now`

Or directly install via:

```
/plugin install contextual-illustrator@vibe-skills
```

After installing, just mention the skill in conversation. For example: "Generate a hero image for this blog post" and the contextual-illustrator skill will be activated automatically.

## Contributing

1. Each plugin lives in its own directory at the repo root, with a `.claude-plugin/plugin.json` manifest and the skill under `skills/<plugin-name>/` (Claude Code auto-discovers any `skills/<name>/SKILL.md`)
2. Every skill must include a `SKILL.md` (instructions for Claude) and a `README.md` (human docs)
3. Register new plugins in `.claude-plugin/marketplace.json` with just `name`, `source`, and `description` — components are discovered from the plugin's own `plugin.json` / `skills/` directory, so don't add a `skills` path here

### Plugin directory structure

```
your-plugin/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest (name, version, description)
└── skills/
    └── your-plugin/
        ├── SKILL.md          # Skill instructions consumed by Claude Code
        ├── README.md         # Human-readable documentation
        ├── .env.example      # API key template (if needed)
        └── scripts/          # Supporting scripts
```

## License

MIT
