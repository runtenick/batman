# batman

Batman is an experimental manager for a personal collection of AI-agent skills. Stable skills live under `skills/` and install as adjusted copies for Codex, GitHub Copilot CLI, or a portable target. Raw third-party trials live under `skills/experimental/` and require an explicit install command.

It grows through personal use and does not promise a stable command or skill catalog.

Inspired by [Matt Pocock's skills](https://github.com/mattpocock/skills) and [pstack](https://github.com/cursor/plugins/tree/main/pstack).

## Install

Clone the repository, then run this command from its root:

```sh
./scripts/install.sh --install-command
```

This installs the skills for Codex and Copilot CLI, then links `batman` into `~/.local/bin`. Add that directory to `PATH` if needed. The link points to the checkout, so the command uses the current repository code.

To install skills without the command link, or to choose one target:

```sh
./scripts/batman sync
./scripts/batman sync --target codex
./scripts/batman sync --target copilot
./scripts/batman sync --target portable
```

`all` means Codex and Copilot, not portable. For `batman` commands, omitting `--target` uses the configured default profile, if set. Otherwise Batman selects the only detected agent or prompts when multiple agents are detected. Batman detects Codex and Copilot from their CLI commands or existing managed skill installs. In non-interactive use without a configured profile, pass `--target` when multiple agents are available. If it detects no agents, standard commands default to `all` and experimental commands default to Codex. The direct `scripts/install.sh` command keeps its default of installing both.

Set a default profile to skip the prompt on future commands:

```sh
batman config set default-profile codex
batman config get default-profile
batman config unset default-profile
```

When a default profile is set, specify `--target copilot` (or another supported target) to use a different target for one command. Batman stores the profile in `$XDG_CONFIG_HOME/batman/default-profile`, or `~/.config/batman/default-profile` when `XDG_CONFIG_HOME` is unset.

| Target | Default destination |
| --- | --- |
| `codex` | `~/.agents/skills` |
| `copilot` | `~/.copilot/skills` |
| `portable` | `~/.agents/skills` |

Override these paths with `BATMAN_CODEX_SKILLS_DIR`, `BATMAN_COPILOT_SKILLS_DIR`, and `BATMAN_PORTABLE_SKILLS_DIR`. Set `BATMAN_BIN_DIR` to change the command location.

The scripts require a POSIX shell and either `sha256sum` or `shasum`.

## Commands

```text
batman sync [--target codex|copilot|portable|all]
batman status [--target codex|copilot|portable|all]
batman enable <skill> [--target codex|copilot|portable|all]
batman disable <skill> [--target codex|copilot|portable|all]
batman update <skill> [--target codex|copilot|portable|all]
batman experimental list [--target codex|copilot|all]
batman experimental add <skill> [--target codex|copilot|all]
batman experimental remove <skill> [--target codex|copilot|all]
batman config get default-profile
batman config set default-profile <codex|copilot>
batman config unset default-profile
```

`status` reports installation, local changes, invocation mode, and available source updates. `enable` allows automatic invocation for one installed target. `disable` returns it to manual-only. `update` refreshes one skill and asks before replacing local changes.

`sync` installs missing skills and updates clean managed copies. It preserves locally modified copies and reports a conflict when both the source and installed copy changed. It also migrates symlinks created by older Batman versions when they point to this checkout.

`experimental list` shows raw skills available for testing. `experimental add` installs one for Codex, Copilot, or both as manual-only. When `--target` is omitted, it follows the detected-agent behavior above. The command does not change the vendored files. `experimental remove` removes the managed copies and asks first if a copy has local changes. Ordinary `sync` ignores experimental skills.

Every stable skill sets `disable-model-invocation: true`, so skills start as manual-only. Copilot and portable copies use that field for their local invocation mode. Codex copies remove the unsupported field and store the local mode as `policy.allow_implicit_invocation` in `agents/openai.yaml`.

To apply the Git standards and approval rules automatically, enable the Git workflow skill after syncing:

```sh
batman enable git-workflow --target codex
```

See [docs/skill-management.md](./docs/skill-management.md) for the state and update model.

## Skills

- `domain-modeling` builds a project glossary and architecture decision records.
- `code-review` reviews a change separately against repository standards and its originating spec.
- `grill-me` interviews the user to resolve decisions in a plan or design.
- `grill-with-docs` combines that interview with domain and architecture notes.
- `grilling` contains the shared interview workflow used by the grill skills.
- `git-workflow` applies Conventional Commit standards and approval rules to Git changes.
- `implement` builds approved work with TDD where it fits, then reviews the result.
- `tdd` guides test-first implementation at agreed public seams.
- `to-spec` turns the current conversation into a spec, using a configured tracker or local Markdown by default.
- `to-tickets` turns a plan or spec into dependency-aware tracer-bullet tickets, using the same destination rules.
- `bro` restates the last message in plain language.
- `unslop` removes common AI writing patterns.

## Experimental skills

- `prototype` is an unmodified copy of Matt Pocock's skill for building throwaway logic or UI experiments. Install it with `batman experimental add prototype --target codex`, `--target copilot`, or `--target all`.

See [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) for sources, adaptations, and licenses.

## Checks

```sh
./scripts/check-skills.sh
sh tests/test-batman.sh
```
