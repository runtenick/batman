# Skill management

This document defines the local state and command contract for installing and managing Batman skills. It does not change the installer by itself.

## State model

Batman keeps state separately for each installation target. The state file lives at:

```text
<skills-directory>/.batman/state.tsv
```

The target-specific files are independent. A skill can be automatic in Codex and manual in Copilot.

The file uses tab-separated records so it remains inspectable without requiring a JSON or YAML parser:

```text
# batman-state-v1
# record<TAB>skill<TAB>value
invocation	unslop	automatic
source-hash	unslop	<hash of the canonical Batman skill>
installed-hash	unslop	<hash of the last rendered installed skill>
```

The records mean:

- `invocation` is either `manual` or `automatic`. Fresh installations without a record use the canonical skill's source default, or `manual` without a source. Existing installations import their current setting.
- `source-hash` identifies the canonical skill content used for the last synchronization.
- `installed-hash` identifies the last installed content, excluding generated invocation metadata.

Stable skills may keep upstream reference files in a top-level `source/` folder.
That folder is excluded from both hashes and installed projections. Refreshing
an upstream snapshot therefore does not create an installation update or conflict.
Experimental skills retain their complete upstream directory in projections.

The invocation preference is local state. Stable skills inherit their source's default invocability; skills without a source are manual by default. The canonical `SKILL.md` preserves the source's invocation field, including omission for model-invoked skills. Fresh installations use this default. Existing local settings take precedence and must not be written back into the repository.

Experimental skills use each target's state file after the owner adds them. Their source path points into `skills/experimental/`, and their installed projections start with the source invocation default and preserve existing local settings.

The hashes allow the manager to distinguish these cases:

- The installed skill matches `installed-hash`, and Batman has a newer `source-hash`: safe update.
- The installed skill differs from `installed-hash`, and Batman has not changed: local modification.
- Both differ: update available with a local conflict.

The manager must never replace a locally modified skill during an ordinary synchronization. An explicit update command may do so only after showing the conflict and requiring confirmation.

## Command contract

The user-facing entry point is `./scripts/batman`. The installer can also place a `batman` symlink in `~/.local/bin` (or `$BATMAN_BIN_DIR`) so the same entry point is available directly as `batman`.

```text
./scripts/batman groups
./scripts/batman scan [<dir>] [--include-unknown]
./scripts/batman status [--target codex|copilot|portable|all] [--group <name>]...
./scripts/batman enable <skill> [--target codex|copilot|portable|all]
./scripts/batman disable <skill> [--target codex|copilot|portable|all]
./scripts/batman sync [--target codex|copilot|portable|all] [--group <name>]...
./scripts/batman update <skill> [--target codex|copilot|portable|all]
./scripts/batman experimental list [--target codex|copilot|all]
./scripts/batman experimental add <skill> [--target codex|copilot|all]
./scripts/batman experimental remove <skill> [--target codex|copilot|all]
./scripts/batman config get default-profile
./scripts/batman config set default-profile <codex|copilot>
./scripts/batman config unset default-profile
```

`all` explicitly selects Codex and Copilot. `config set default-profile codex|copilot` chooses the target Batman uses when `--target` is omitted; the profile is stored at `$XDG_CONFIG_HOME/batman/default-profile` or `~/.config/batman/default-profile`. Use `config get default-profile` to display it and `config unset default-profile` to clear it. With a default profile set, Batman never prompts: pass `--target` to use another target for one command.

Without a configured profile, Batman selects the only detected agent. When
both are detected, it asks which to use and offers to save the choice as the
default. Declining keeps the choice for that command only. In non-interactive
use with both agents and no default, pass `--target`.

Detection checks for the terminal command or Batman-managed skill copies in
the agent's folder, including older symlinks. Portable copies do not establish
that Codex is installed. Detection can miss editor integrations or find old
copies after an agent is removed.

If neither agent is detected, ordinary skill commands use portable mode and
explain the destination. Experimental commands require an explicit Codex or
Copilot target in that case. Read-only `groups`, `scan`, and help need no agent
choice; `scan` does not use a saved default.

Run `./scripts/install.sh` to set up only the command. It does not install skills
or change agent configuration. Old installer target and group options belong
on `batman sync`; old `--install-command` usage becomes `./scripts/install.sh`,
followed by `batman sync --target all` only if both skill installations are wanted.
The link points at this checkout, which must remain available. Existing unrelated
commands are preserved, and setup explains how to add the command folder to PATH.

Running `batman` without arguments succeeds with brief introductory help.
Each command and config or experimental subcommand supports `--help`, including
before a required skill name. Help performs no installation, source validation,
agent selection, or configuration changes.

### Groups

`groups` lists stable skills and their group, including skills with no group.
It does not require a target. `skills/groups.tsv` records membership and direct
dependencies using three tab-separated fields:

```text
# skill<TAB>group<TAB>dependencies
grill-me	dev-workflow	grilling
grill-with-docs	dev-workflow	grilling,domain-modeling
grilling	dev-workflow	-
```

Use `-` when a skill has no dependencies. Grouped skills live at
`skills/<group>/<name>`. Ungrouped skills live at `skills/<name>` and have no
manifest entry. Record dependencies when adding or changing skills. The checker
validates declared dependencies; it does not infer them from skill prose.
It rejects malformed rows, duplicate names or membership, unknown skills,
membership that differs from the directory layout, and dependencies outside the
skill's group. Checking every direct dependency keeps transitive
dependencies together too.

The groups are `dev-workflow` and `communication`. Installed directories
remain flat at `<skills-directory>/<name>`. Skills in the same group remain siblings in both
layouts. Discovery excludes experimental skills and upstream `source/` snapshots.
Experimental skills retain their separate manifest and installation commands.

### `scan`

`scan` is a read-only installation inventory. It includes unmanaged skills and
does not use agent executable detection, `--target`, or the default profile.
With no directory argument, it searches beneath the nearest Git project root,
including worktrees, or beneath the current directory when outside a project.
An explicit directory limits the recursive search to that directory. Known
global skill locations are checked in either case.

Recognized conventions are:

| Location | Scope | Convention |
| --- | --- | --- |
| `~/.agents/skills/<skill>/SKILL.md` | Global | Codex, Copilot |
| `~/.copilot/skills/<skill>/SKILL.md` | Global | Copilot |
| `/etc/codex/skills/<skill>/SKILL.md` | Global | Codex |
| `<project-or-subdirectory>/.agents/skills/<skill>/SKILL.md` | Project | Codex, Copilot |
| `<project-or-subdirectory>/.github/skills/<skill>/SKILL.md` | Project | Copilot |
| `<project-or-subdirectory>/.claude/skills/<skill>/SKILL.md` | Project | Copilot |

The scan also checks Batman's configured Codex and Copilot destinations, using
`BATMAN_CODEX_SKILLS_DIR`, `BATMAN_SKILLS_DIR`, and
`BATMAN_COPILOT_SKILLS_DIR`. These are additional global locations; standard
locations are still checked. The conventions follow the official
[Codex skill locations](https://learn.chatgpt.com/docs/build-skills#where-codex-loads-local-skills)
and [Copilot CLI skill locations](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#skill-locations).

Each installation gets a row with its frontmatter name, falling back to the
directory name, scope, and absolute path. When recognized installations match
more than one agent convention, a `Convention` column identifies the matches.
Shared locations list both conventions. Duplicate skill names at different
installation paths remain separate rows. Aliases of the same containing root
are resolved to avoid counting the same installation twice; linked skill
folders retain their installation paths.

```text
Skill                    Scope      Convention         Location
deploy                   Project    Copilot            /projects/app/.github/skills/deploy
grill-me                 Global     Codex, Copilot     /home/user/.agents/skills/grill-me

4 skills found outside recognized installation locations.
Use --include-unknown to view them.
```

The recursive search counts other `SKILL.md` files as unknown, including
reference snapshots and source copies. `--include-unknown` adds their rows with
scope `Unknown`; it does not change the search boundaries. Git object stores
are excluded. Installed skill-folder links and links to project skill roots
are inspected, but arbitrary directory symlinks are not recursively followed.
Unreadable search paths produce an incomplete-scan warning and a nonzero exit.

Scope is inferred from the location. A project row identifies an installation
for that project or subtree, not availability everywhere beneath the requested
search directory. The scan does not evaluate agent configuration overrides,
disabled skills, name precedence, plugins, remote skills, or bundled skills.
It does not establish whether an agent actually discovered or loaded a skill.

### `status`

`status` is read-only. It reports one row per installed or available skill and includes:

- the target;
- the invocation mode, `manual` or `automatic`;
- the local content state, such as `missing`, `clean`, `modified`, or `conflict`;
- whether a Batman update is available.

Example:

```text
Skill      Target   Invocation   Local state   Update
unslop     codex    automatic     clean         current
to-spec    codex    manual        clean         available
grill-me   codex    manual        modified      available
```

Use `--group <name>` to limit rows to one group. Repeat the option to show
multiple groups. Without it, status covers every stable skill.

### `enable` and `disable`

These commands change only the selected target's local invocation preference. They do not modify Batman's canonical source files.

- `enable` sets `automatic`.
- `disable` sets `manual`.
- A missing preference is treated as `manual`.

The command also regenerates the target's invocation metadata so the active harness sees the new setting.

### `sync`

`sync` adds missing skills and updates installed skills that have not been locally modified. It preserves local invocation preferences, reports local modifications, and does not overwrite conflicts.

Use `--group <name>` to synchronize only that group. Repeat the option to combine
groups. Duplicate selections have no additional effect. Without group selection,
sync covers all stable skills, including ungrouped skills. It does not remove
installed skills outside the selection or store a default group selection.
Unknown groups fail before any installation changes.

When syncing all targets, identical outcomes are grouped onto one row per skill with the targets listed together. Different outcomes remain on separate target-specific rows. The summary counts operations per target.

### `update`

`update <skill>` handles one skill explicitly. If the installed copy is clean, it updates it. If it has local changes, it shows the conflict before asking for permission to replace the copy.

### `experimental`

Experimental skills are raw copies of third-party sources under `skills/experimental/<name>`. `sources.tsv` pins each copy to a repository, commit, upstream path, and content hash. The repository check rejects any drift, including extra files. If an upstream skill does not supply `agents/openai.yaml`, Batman may add that file and records its origin in the manifest.

`experimental list` reports the available experiments and their installation state for Codex, Copilot, or both. `experimental add <skill>` installs or refreshes one experiment for the selected target. Codex adds `policy.allow_implicit_invocation` and Copilot adds `disable-model-invocation` to reflect the source default or existing local setting. The vendored files remain unchanged. `experimental remove <skill>` removes only a copy managed from the matching experimental source. It asks before removing local changes.

Experimental commands support `codex`, `copilot`, and `all`. Codex remains the default. Ordinary `sync`, `status`, `enable`, `disable`, and `update` continue to manage stable skills only. Promoting an experiment into the stable skill collection is a separate repository change after real use supports adaptation.

## Migration

When a stable skill moves from `skills/<name>` to `skills/<group>/<name>`, Batman
recognizes installed copies and legacy symlinks that reference the previous flat
source path. Sync records the new path while preserving local edits, invocation
preferences, and content baselines. Status and individual management commands also
recognize the previous path before sync. Installed directory names do not change.

The first state-aware run must import the existing installation before changing it:

1. Read the current invocation setting from the installed target.
2. Record it as the local preference.
3. Record the installed content hash as the baseline.
4. Leave the installed skill unchanged unless the user explicitly requests an update.

This preserves existing choices such as making `unslop` automatic.
