# Batman backlog

Make Batman easy for a newcomer to find skills, install a useful selection,
choose when to update, and control automatic invocation.

Keep the main command set small, explain commands in plain language, and make
outputs show what happened and what needs attention. These requirements apply
to every ticket.

## Suggested order

| Order | Ticket | Starting point | Size |
| --- | --- | --- | --- |
| 1 | [Simplify help and first-time setup](https://github.com/runtenick/batman/issues/1) | Commands exist, but help is dense and setup also installs skills. | Small to medium |
| 2 | [Find skills and ready-made packages](https://github.com/runtenick/batman/issues/4) | Groups list names. Descriptions and search are missing. | Medium |
| 3 | [Install selected skills and packages](https://github.com/runtenick/batman/issues/5) | Group selection exists. Individual installation and separation from updates are missing. | Medium |
| 4 | [Optional updates that protect edits](https://github.com/runtenick/batman/issues/6) | Local change detection exists. Upstream checks, previews, and retained backups are missing. | Large |
| 5 | [Readable status and summaries](https://github.com/runtenick/batman/issues/3) | Status and scan exist. Their presentation needs work. | Small to medium |
| 6 | [Explicit manual and automatic invocation](https://github.com/runtenick/batman/issues/7) | Stable-skill controls exist. Improve wording and cover managed experimental skills. | Small |
| 7 | [Portable personal skill selections](https://github.com/runtenick/batman/issues/2) | Ready-made groups exist. Personal selections are new. | Medium |
| 8 | [Package Batman as an installable CLI](https://github.com/runtenick/batman/issues/8) | The command runs from a checkout. Distribution and releases are missing. | Medium |

Sizes are planning estimates, not measured effort. Each ticket contains its
scope, acceptance criteria, and limits.

Start with help and setup so users have a clear entry point. Then let them
choose and install skills before extending updates. Build personal packages
on those existing operations. Invocation clarity can move earlier if it is
the immediate problem; it only needs the command vocabulary agreed in ticket 1.
Every feature ticket should keep its help, output, and documentation readable
as it is implemented.
Finish by choosing a distribution method and packaging Batman so users can
install the command without cloning the repository.

## Package scope

A ready-made package is a selection of skills from this repository. Existing
groups are the starting point. A personal package saves a user's own selection
of Batman skills in a portable manifest for installation on another machine.
It does not back up edits to installed skill files. Custom skill publishing is
outside this backlog.

## Decisions and boundaries

- Ticket 1 settles command names. The suggested `find`, `install`, `list`,
  `update`, `mode`, and `pack` commands are proposals, not adopted behavior.
- Installation should leave existing copies alone. Updates should be explicit.
- Preserve local edits and invocation preferences. Replacing edits requires
  inspection, confirmation, and a recoverable backup.
- Skills start manual-only. Experimental installation remains an explicit choice,
  and vendored source files remain unchanged.
- Keep existing commands compatible or document their migration.
- Defer a marketplace, accounts, custom-skill publishing, automatic merging,
  background updates, a dashboard, and extra diagnostic commands.

This backlog authorizes no implementation by itself. Pick one ticket when ready
to work on its behavior. Tickets 1, 2, and 3 revise existing issues; the other
five are new.
