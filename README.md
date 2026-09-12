# Batman

Batman doesn’t need superpowers. Just the right skills.

My personal collection of skills and notes for working with AI. I explore other people's skills, try them in daily development, keep what helps, and write my own when useful. The workflow will develop through use.

Inspired by [Matt Pocock's skills](https://github.com/mattpocock/skills) and [pstack](https://github.com/cursor/plugins/tree/main/pstack).

## Install

Clone Batman, then run:

```sh
./scripts/install.sh
```

The installer links every folder under `skills/` into `~/.agents/skills`, which Codex and other agents can discover as personal skills. Because these links point back to the clone, updating the clone also updates the shared skills.

It also creates managed copies under `~/.copilot/skills` for Copilot CLI. Codex and Copilot use different metadata for manual-only skills, so these copies add Copilot's `disable-model-invocation` field when the canonical skill's `agents/openai.yaml` disables implicit invocation. Run the installer again after updating the clone to refresh the Copilot copies. Existing files that Batman does not manage are never replaced.

Set both destination variables to test or use other locations:

```sh
BATMAN_SKILLS_DIR=/path/to/shared-skills \
BATMAN_COPILOT_SKILLS_DIR=/path/to/copilot-skills \
./scripts/install.sh
```

The installer does not replace existing files or links. Move or remove a conflicting destination yourself, then run it again.

Manual-only skills use harness-specific invocation syntax:

- Codex: `$grill-me`, `$grill-with-docs`, or `$unslop`
- Copilot CLI: `/grill-me`, `/grill-with-docs`, or `/unslop`

## Included skills

- `unslop` removes common AI writing patterns.
- `grill-me` interviews you until a plan or design has no unresolved decisions.
- `grill-with-docs` runs the same interview while maintaining domain language and recording qualifying architecture decisions.

The two grill entry points share the internal `grilling` skill. `grill-with-docs` also uses `domain-modeling` and its document formats. See [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) for sources, local adaptations, and licenses.
