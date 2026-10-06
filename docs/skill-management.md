# Skill management

Batman manages one shared installation for Codex and Copilot at
`~/.agents/skills`. `BATMAN_SKILLS_DIR` overrides the destination. Commands
operate without agent detection or a saved profile.

## State and invocation

The shared state file is `<skills-directory>/.batman/state.tsv`:

```text
# batman-state-v1
# record<TAB>skill<TAB>value
invocation\tunslop\tautomatic
source-hash\tunslop\t<hash of the canonical Batman skill>
installed-hash\tunslop\t<hash of the last rendered installed skill>
```

`invocation` records one manual or automatic preference per skill. Fresh
installations inherit their source defaults; existing local choices take
precedence. `source-hash` identifies the canonical content last synchronized.
`installed-hash` identifies the last installed content, excluding generated
invocation settings.

Installed copies express the same preference in two formats:

- Copilot reads `disable-model-invocation` in `SKILL.md`.
- Codex reads `policy.allow_implicit_invocation` in `agents/openai.yaml`.

`enable` and `disable` update both formats and the saved preference. They do
not edit canonical source files. Borrowed source directories remain identical
to upstream, including metadata and supporting files. `skills/sources.tsv`
records repository, path, ref, commit, and content hash. The checker validates
those canonical bytes. Git history preserves previous revisions.

The source directory hash is SHA-256 of sorted `./path<TAB>file-sha256` lines,
with a newline after each line, using C locale ordering. Installation hashes
exclude the ownership marker and normalize generated invocation settings.
Batman adds `scripts/codex-metadata/<skill>.yaml` only when upstream supplies no
metadata. These external files participate in source update detection.

The hashes distinguish safe updates, local modifications, and conflicts.
Ordinary synchronization preserves local modifications. Explicit `update`
asks before replacing local edits or a copy with no recorded baseline.

## Commands

```text
batman groups
batman scan [<dir>] [--include-unknown]
batman status [--group <name>]...
batman sync [--group <name>]...
batman enable <skill>
batman disable <skill>
batman update <skill>
batman experimental list
batman experimental add <skill>
batman experimental remove <skill>
```

Run `./scripts/install.sh` to link the command into `~/.local/bin`, or
`$BATMAN_BIN_DIR`. It installs no skills. The link uses this checkout's code
and sources. `sync` copies local sources; it does not fetch upstream updates.

Help is read-only and runs before source validation or installation state is
loaded. Running `batman` without arguments prints brief introductory help.

### Groups

`groups` lists stable skills and their group, including ungrouped skills.
`skills/groups.tsv` records membership and direct dependencies:

```text
# skill<TAB>group<TAB>dependencies
grill-me\tdev-workflow\tgrilling
grill-with-docs\tdev-workflow\tgrilling,domain-modeling
grilling\tdev-workflow\t-
```

Grouped sources live at `skills/<group>/<name>`. Ungrouped sources live at
`skills/<name>`. Installed directories remain flat. Each skill belongs to at
most one group; dependencies belong to that same group. The checker rejects
malformed rows, duplicate names, missing skills, layout mismatches, and
cross-group dependencies. Discovery excludes `skills/experimental/`.

Repeat `--group` to select multiple groups for sync or status. Omitting it
selects every stable skill. Unknown groups fail before installation changes.
Selection does not remove other installed skills or save a default group.

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

The scan also checks Batman's shared destination and configured legacy folders,
using `BATMAN_SKILLS_DIR`, `BATMAN_CODEX_SKILLS_DIR`,
`BATMAN_PORTABLE_SKILLS_DIR`, and `BATMAN_COPILOT_SKILLS_DIR`. These are additional global locations; standard
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
downloaded references and repository skill copies. `--include-unknown` adds their rows with
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

Status is read-only. It prints the shared destination and one row per stable
skill with invocation mode, local state, and whether a checkout update is
available. Local states include `missing`, `clean`, `modified`, `untracked`,
and `conflict`. Use `scan` to find copies in legacy or unmanaged locations.

### `sync`

Sync adds missing stable skills and refreshes clean managed copies. It
preserves local edits and invocation preferences, reports conflicts, and
returns nonzero when any conflict remains. The summary counts skills once.
It writes both agents' invocation metadata, including for preserved copies.

### `update`, `enable`, and `disable`

Update refreshes one installed stable skill from this checkout. It asks before
replacing local changes or a copy with no baseline. Enable sets automatic
invocation; disable sets manual invocation. These commands operate on the
shared installation. Run sync first to migrate an older installation.

### `experimental`

Experiments live under `skills/experimental/<name>` and need no integrity
manifest. List reports available experiments and their shared installation
state. Add installs or refreshes one clean copy, preserving local preferences
and edits. Remove deletes a managed copy and asks before removing local edits.
Add and remove first migrate legacy copies of that experiment.

Ordinary sync migrates already installed experiments when no groups are
selected, but does not install new experiments or refresh their content. Use
experimental add to refresh one. Promotion to stable remains an explicit
repository change.

## Migration

Sync first converts existing managed copies to shared metadata. It then
migrates managed copies from older destinations into the shared folder.
Group selection limits migration to those stable skills; without groups,
installed experiments and older managed skills are included too.

Before conversion or removal, Batman copies the original files, their state
records, and their installation path into a unique directory under
`~/.agents/.batman-archive`. For custom destinations the default archive is
`<skills-parent>/.batman-archive`. Set `BATMAN_ARCHIVE_DIR` to override it.
Archives sit outside skill discovery folders and are never deleted by sync.

Migration preserves recorded invocation preferences and content baselines.
A legacy copy with local edits moves with those edits intact and remains
modified. Copies without historical baselines are compared with a pristine
current projection, so differing content remains protected from automatic
replacement. Previous flat source paths and managed skill symlinks remain
recognized.

If both locations have a copy, migration compares normalized content and
invocation preferences. Matching copies collapse into one shared installation,
with the old copy archived. Differing copies remain in place and produce a
conflict with both paths. Migration conflicts stop source synchronization. Review the copies, preserve the desired content and
preference, and move the unwanted copy outside skill discovery before syncing
again. Unmanaged skills are never migrated or overwritten.

Older removed skills retain their content during conversion; sync does not
remove them. Scan can locate them even though status lists only stable sources.

`--target codex|copilot|portable|all` remains accepted as a deprecated alias;
every value selects the shared installation. Saved default profiles are
ignored. `config get default-profile` explains the retirement, and
`config unset default-profile` removes an old setting. New profiles are rejected.

`BATMAN_CODEX_SKILLS_DIR` and `BATMAN_PORTABLE_SKILLS_DIR` remain destination
fallbacks after `BATMAN_SKILLS_DIR`. `BATMAN_COPILOT_SKILLS_DIR` specifies a
legacy location for migration and scanning. With a custom shared destination,
only explicitly configured legacy locations are migrated. This keeps isolated
installs and tests from changing ordinary home installations.
