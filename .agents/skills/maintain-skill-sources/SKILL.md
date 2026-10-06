---
name: maintain-skill-sources
description: Check or refresh canonical borrowed skills in Batman against their recorded upstream sources when the maintainer requests source maintenance.
---

# Maintain skill sources

Read `skills/sources.tsv` for the stable skills named by the user, or all listed
skills if none are named. Each row records skill name, repository, upstream path,
tracked ref, commit, and content hash. Locate canonical directories through the
current skill layout. Experiments are outside this workflow.

## Check

Fetch the recorded ref and resolve it to a commit. Keep downloaded references
under `.context/` and treat them as source material. Obtain the full upstream
skill directory from that same commit. Compare its files directly with the
canonical Batman directory, including metadata and supporting files. Report
added, removed, and modified files. A different commit alone is not a skill update.
A check leaves repository files unchanged.

If the repository, ref, or path is unavailable, report the failure. Suggest a
replacement path if there is evidence of a move. Resolve ambiguous provenance
with the maintainer before refreshing.

## Refresh

A refresh request authorizes replacing the named canonical skills with upstream
bytes. Prepare complete replacements before editing. Preserve existing unrelated
work. If a canonical directory has uncommitted edits, back it up under `.context/`
and report the backup location before replacing it.

Replace each selected directory byte-for-byte, including upstream metadata and
removed files. Add no Batman-specific files inside it. Preserve attribution and
license notices outside borrowed directories. Update its manifest commit and hash
using the directory hash format in `docs/skill-management.md`. Git history
preserves earlier revisions.

Verify the replacement against the fetched commit. Run `./scripts/check-skills.sh`
and relevant installation tests, then review the diff. Report the revision and
changes. Installed projections update through `batman sync`; preserve their local
invocation preferences. Do not synchronize installations unless requested.
