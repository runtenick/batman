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

Browse the skills, install them, and check the result:

```sh
batman groups
batman sync
batman status
```

Batman installs one shared copy of each skill in `~/.agents/skills`. Codex and
Copilot both load skills from that folder. No agent selection or saved default
profile is needed. Set `BATMAN_SKILLS_DIR` to use a different destination.
Setup links the command to this checkout, so local repository changes are
available immediately; synchronization updates the installed skill copies.
Batman does not fetch repository or upstream updates.

`sync` installs missing stable skills and refreshes clean managed copies. It
preserves local edits and invocation preferences. Skills under evaluation are
added separately.

To install selected groups, repeat `--group` as needed:

```sh
batman sync --group dev-workflow
batman sync --group dev-workflow --group communication
batman status --group communication
```

Without `--group`, synchronization covers all stable skills, including
ungrouped skills. Group selection leaves other installed skills untouched.

Set `BATMAN_BIN_DIR` to change the command location. The scripts require a
POSIX shell and either `sha256sum` or `shasum`.

## Commands

```text
batman groups
batman scan [<dir>] [--include-unknown]
batman sync [--group <name>]...
batman status [--group <name>]...
batman enable <skill>
batman disable <skill>
batman update <skill>
batman experimental list
batman experimental add <skill>
batman experimental remove <skill>
```

Use `batman <command> --help` for instructions and examples.

`status` reports installation, local changes, invocation mode, and updates
available from this checkout. `enable` allows automatic invocation in both
agents. `disable` returns a skill to manual-only use. `update` refreshes one
skill and asks before replacing local changes.

`scan` inventories local skills, including skills Batman did not install.
It checks known global locations and searches the current Git project, or the
current directory outside a Git project. Pass a directory to search beneath it,
for example `batman scan ~/projects`. The report shows each skill's name,
inferred scope, and absolute installation path. Multiple installations remain
separate rows so legacy duplicates are visible. Other `SKILL.md` files are
counted at the end; `--include-unknown` shows their paths. See
[scan conventions and limits](./docs/skill-management.md#scan).

`sync` reports a conflict when both the source and installed copy changed.
It also migrates older Batman copies into the shared installation. Previous
copies are archived outside the skill search folders before conversion or
removal. If legacy copies differ in content or invocation preference, Batman
reports both paths and preserves both copies. See
[migration details](./docs/skill-management.md#migration).

`experimental list` shows skills under evaluation. `experimental add` installs
or refreshes one. `experimental remove` removes a managed copy and asks first
if it has local changes. Ordinary `sync` excludes new experiments, but migrates
already installed experimental copies.

Borrowed stable directories remain byte-for-byte identical to upstream.
`skills/sources.tsv` records their provenance and content hashes.
Batman-specific behavior belongs in tooling or separate owned skills.
Installed copies carry both `disable-model-invocation` in `SKILL.md` and
`policy.allow_implicit_invocation` in `agents/openai.yaml`, expressing the same
local preference for Copilot and Codex. Canonical source files stay unchanged.

### Older commands and installations

Old `--target codex|copilot|portable|all` options remain deprecated aliases.
They all use the shared installation and never create a second set of skills.
Saved `default-profile` settings are ignored. Clear one with
`batman config unset default-profile`; setting a new profile is no longer supported.

The old `BATMAN_CODEX_SKILLS_DIR` and `BATMAN_PORTABLE_SKILLS_DIR` variables
remain destination fallbacks. Prefer `BATMAN_SKILLS_DIR`.
`BATMAN_COPILOT_SKILLS_DIR` identifies a legacy folder to migrate and scan.
When using a custom shared destination, Batman migrates only legacy locations
you explicitly configure; it leaves ordinary home installations alone.

`./scripts/install.sh` sets up only the command. Replace old installer skill
options with `batman sync`, optionally adding `--group`. Running setup again
for the same checkout leaves its command link in place. Setup refuses to
replace an unrelated command.

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

- `prototype` is an unmodified copy of Matt Pocock's skill for building throwaway logic or UI experiments. Install it with `batman experimental add prototype`.

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
