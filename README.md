# batman

Batman doesn’t need superpowers. Just the right skills.

My personal collection of skills and notes for working with AI. I explore other people's skills, try them in daily development, keep what helps, and write my own when useful. The workflow will develop through use.

Inspired by [Matt Pocock's skills](https://github.com/mattpocock/skills) and [pstack](https://github.com/cursor/plugins/tree/main/pstack).

## Install

Clone Batman, then run:

```sh
./scripts/install.sh
```

With no arguments, the installer creates managed copies for both Codex and Copilot CLI. You can instead choose one installation format explicitly:

```sh
./scripts/install.sh --target codex
./scripts/install.sh --target copilot
./scripts/install.sh --target portable
./scripts/install.sh --target all
```

`all` is the default and installs the `codex` and `copilot` targets. The destinations are:

- `codex`: `~/.agents/skills`
- `copilot`: `~/.copilot/skills`
- `portable`: `~/.agents/skills`, intended for a non-Codex setup

Every Batman skill is manual-only by default. The canonical source of truth is `disable-model-invocation` in each `SKILL.md`: `true` means manual-only, while changing it to `false` is the explicit opt-in to automatic invocation.

Portable and Copilot installations preserve the canonical skill unchanged. Codex does not accept that portable frontmatter field, so its managed copy removes the field and translates it to the supported `policy.allow_implicit_invocation` setting in `agents/openai.yaml`. Run the installer again after updating the clone to refresh managed copies. The installer also migrates symlinks created by older Batman versions when they point to the same clone; it never replaces unrelated files or links.

Before writing an installation, the installer checks every skill. It requires exactly one boolean `disable-model-invocation` value and rejects a canonical Codex invocation policy, avoiding two sources of truth. When adding an external skill, translate any harness-specific invocation setting to that canonical field while preserving its intent, attribution, and required notices.

Override destinations with target-specific variables. `BATMAN_SKILLS_DIR` remains a compatible fallback for the Codex and portable destinations:

```sh
BATMAN_CODEX_SKILLS_DIR=/path/to/codex-skills \
BATMAN_COPILOT_SKILLS_DIR=/path/to/copilot-skills \
./scripts/install.sh

BATMAN_PORTABLE_SKILLS_DIR=/path/to/agent-skills \
./scripts/install.sh --target portable
```

If a destination conflicts with something Batman does not manage, move or remove that destination yourself and run the installer again.

Manual-only skills use harness-specific invocation syntax:

- Codex: `$grill-me`, `$grill-with-docs`, or `$unslop`
- Copilot CLI: `/grill-me`, `/grill-with-docs`, or `/unslop`

Run the policy check directly with:

```sh
./scripts/check-skills.sh
```

## Included skills

- `unslop` removes common AI writing patterns.
- `grill-me` interviews you until a plan or design has no unresolved decisions.
- `grill-with-docs` runs the same interview while maintaining domain language and recording qualifying architecture decisions.

The two grill entry points share the internal `grilling` skill. `grill-with-docs` also uses `domain-modeling` and its document formats. See [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) for sources, local adaptations, and licenses.
