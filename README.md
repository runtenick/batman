# batman

Batman doesn't need superpowers. Just skills.

---

This repo is __two things.__
- my personal collection of skills for software development
- a work in progress skill manager for coding agents

## Install

Clone the repository, then make `batman` available as a command:

```sh
git clone https://github.com/runtenick/batman.git
cd batman
./scripts/install.sh
batman
```

Setup installs only the command. It links `batman` into `~/.local/bin` and
shows how to add that directory to `PATH` if needed. Keep the checkout: the
command uses its current code and bundled skills.

Browse the skills, install a group, and check the result:

```sh
batman groups
batman sync --group dev-workflow
batman status
```

`sync` installs missing skills and refreshes clean managed copies. Omit
`--group` to synchronize all stable skills. Skills under evaluation are added
separately. Use `batman <command> --help` for instructions and examples,
including `batman enable --help` before choosing a skill.

Choose a group to install only its skills. Repeat `--group` to combine groups:

```sh
batman groups
batman sync --group dev-workflow --target codex
batman sync --group dev-workflow --group communication --target codex
batman status --group communication --target codex
```

Without `--group`, synchronization covers all stable skills, including
ungrouped skills. Group selection leaves other installed skills untouched.

Batman uses your saved default agent if you have one. Otherwise, it uses the
only agent it finds. If it finds both Codex and Copilot, it asks which to use
and offers to save that choice as your default. In scripts, choose an agent
explicitly with `--target` or save a default first.

Detection checks for a `codex` or `copilot` terminal command or Batman-managed
skill copies in that agent's folder. It is an inference: editor integrations
may be missed, and old skill copies can remain after an agent is removed.
Portable copies alone do not count as Codex installations.

If neither agent is found, ordinary skill commands use portable mode and show
the destination, `~/.agents/skills` by default. This gives you skill files with
their source invocation defaults without requiring an agent. Experimental commands require a Codex or
Copilot choice. Pass `--target` to choose explicitly:

```sh
batman sync --target codex
batman sync --target copilot
batman sync --target portable
```

`--target all` selects Codex and Copilot together.

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

### Migrating old installer commands

`./scripts/install.sh` now sets up only the command and takes no installation
options. Replace earlier usage as follows:

| Earlier command | Current commands |
| --- | --- |
| `./scripts/install.sh --install-command` | `./scripts/install.sh`, then `batman sync --target all` if you also want skills for both agents |
| `./scripts/install.sh` to install all skills | `batman sync --target all` |
| `./scripts/install.sh --target codex --group communication` | `batman sync --target codex --group communication` |

Setup refuses to replace an existing unrelated command. Running it again for
the same checkout leaves the command link in place.

## Commands

```text
batman groups
batman scan [<dir>] [--include-unknown]
batman sync [--target codex|copilot|portable|all] [--group <name>]...
batman status [--target codex|copilot|portable|all] [--group <name>]...
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

`scan` inventories local skills, including skills Batman did not install. It
shows a loading spinner in a terminal, clearing it before displaying the report.
Redirected output does not include the spinner. The scan
checks known global locations and searches the current Git project, or the
current directory outside a Git project. Pass a directory to search beneath it
instead, for example `batman scan ~/projects`.

The report shows each skill's name, inferred scope (`Global` or `Project`), and
absolute installation path. When locations match both Codex and Copilot
conventions, it also shows a `Convention` column. Multiple installations of the
same skill remain separate rows. Scope comes from installation conventions,
not from detecting agent executables or observing a session.

Other `SKILL.md` files, such as source copies or downloaded examples, are counted
at the end. Use `batman scan --include-unknown` to show their paths with scope
`Unknown`. Scanning does not change skills or configuration, and does not use
the configured default profile. See [scan conventions and limits](./docs/skill-management.md#scan)
for the recognized locations.

`sync` installs missing skills and updates clean managed copies. It preserves locally modified copies and reports a conflict when both the source and installed copy changed. It also migrates symlinks created by older Batman versions when they point to this checkout.

`experimental list` shows skills the owner has not fully validated or committed to the stable set. `experimental add` installs one for Codex, Copilot, or both. `experimental remove` removes a managed copy and asks first if it has local changes. Ordinary `sync` excludes this folder.

Borrowed stable directories remain byte-for-byte identical to upstream. `skills/sources.tsv` records their provenance and content hashes. Batman-specific behavior belongs in tooling or separate owned skills. To customize a third-party skill, rename it and treat it as your own.

Prefer manual invocation for top-level workflows. Automatic invocation fits behavior that should generally apply and dependencies other skills invoke. Borrowed skills preserve upstream defaults. Installed local preferences take precedence. Copilot and portable projections use `disable-model-invocation`; Codex projections use `policy.allow_implicit_invocation` in `agents/openai.yaml`.

See [docs/skill-management.md](./docs/skill-management.md) for the state and update model.

## Skills

Each skill belongs to one group or none. Dependencies stay in the same group.
`batman groups` lists membership without requiring an installation target.

The repository mirrors those groups:

```text
skills/
├── dev-workflow/       # Eleven workflow skills, including dependencies
├── communication/      # bro and unslop
├── writing-for-agents/
├── experimental/
└── groups.tsv
```

Batman installs each skill directly into the target's skills directory.

### dev-workflow

The development workflow runs from grilling through specs, tickets,
implementation, and review. It includes the skills those stages depend on.

- `grill-me` interviews the user to resolve decisions in a plan or design.
- `grill-with-docs` combines that interview with domain and architecture notes.
- `grilling` contains the shared interview workflow used by `grill-me` and `grill-with-docs`.
- `domain-modeling` builds a project glossary and architecture decision records.
- `setup-matt-pocock-skills` configures each project's issue tracker and domain doc layout. Run it manually once per project; choose local Markdown to keep work under `.scratch/`.
- `to-spec` turns the current conversation into a spec using the configured tracker.
- `to-tickets` turns a plan or spec into dependency-aware tracer-bullet tickets using the configured tracker.
- `implement` builds approved work with TDD where it fits, reviews it, and commits to the current branch.
- `codebase-design` provides shared guidance for module interfaces, test seams, and comparing design alternatives.
- `tdd` guides test-first implementation at agreed public seams.
- `code-review` runs parallel reviews against repository standards and the originating spec.

### communication

- `bro` restates the last message in plain language.
- `unslop` removes common AI writing patterns.

### Ungrouped

- `writing-for-agents` guides writing skills, agent instructions, and other documents agents consume.

## Experimental skills

- `prototype` is an unmodified copy of Matt Pocock's skill for building throwaway logic or UI experiments. Install it with `batman experimental add prototype --target codex`, `--target copilot`, or `--target all`.

See [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) for sources and licenses.

Use the repository-local `$maintain-skill-sources` skill to check or refresh
canonical upstream skills, for example "Use $maintain-skill-sources to check
implement". Checks compare the Batman directory directly with upstream;
refreshes replace it with upstream bytes and update the manifest. Git history
preserves earlier revisions. The maintenance skill lives under `.agents/skills/`
and is manual-only; Batman does not install it globally.

## Checks

See the [ordered backlog](./docs/backlog.md) for planned usability improvements
and their GitHub tickets.

```sh
./scripts/check-skills.sh
sh tests/test-batman.sh
```

---

Inspired by [Matt Pocock's skills](https://github.com/mattpocock/skills) and [pstack](https://github.com/cursor/plugins/tree/main/pstack).
