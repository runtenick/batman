# Matt v1.3 follow-up

This handoff records the October 5, 2026 review of
[Matt's v1.3 changelog](https://www.aihero.dev/skills/skills-changelog-v13-implement-spec-pr-retro-and-glossary-md).
This is a historical record. The October 5 upstream reset supersedes the
adaptations below. The canonical upstream model in `skill-management.md`
supersedes its snapshot and experimental-manifest guidance. Pending items require
separate selection by the owner.

## Adopted glossary convention

Batman now uses `GLOSSARY.md` and `GLOSSARY-MAP.md` in the active
`domain-modeling` and `tdd` skills. The root glossary is `GLOSSARY.md`, and the
domain-modeling template is `GLOSSARY-FORMAT.md`. Glossary content and the
invocation defaults were preserved during that migration. The later invocation
policy change is recorded below.

Other projects using these skills need their old glossary filenames and
references migrated together. Confirm that an existing `CONTEXT.md` is a domain
glossary before renaming it, and check for an existing `GLOSSARY.md` to avoid
overwriting or splitting the vocabulary.

## Dependency loading, adopted after review

The owner subsequently chose Matt's dependency invocation format. `grill-me`
and `grill-with-docs` now call the Skill tool with their included dependencies,
and `implement` explicitly calls it with "tdd" instead of a bare `/tdd` mention.
This wording requests skill invocation through the agent's available mechanism;
it does not require Claude Code or a literal tool named `Skill`.

Stable skills now inherit their source's default invocability, including their upstream invocation metadata. Skills without a source are manual by default.
Fresh installations use these defaults; existing local invocation settings are
preserved. Experimental projections also inherit source defaults after explicit
addition. Model choice remains under the owner's control.

## Implementation close-out, adopted after review

The owner chose to remove Batman's custom Git restrictions and use Matt's
skills as the starting point. `implement` now ends with code review and a
commit to the current branch, matching the saved upstream workflow.

Implementation close-out reviews against `HEAD`, including staged, unstaged,
and new files. `code-review` retains the three-dot comparison for committed
branch reviews and uses the merge-base to include working-tree changes for
work-in-progress reviews. It scopes out unrelated files and hunks. The
Standards and Spec axes remain separate.

The source-maintenance skill's separate commit-authorization requirement was
removed too. Borrowed skill content remains unchanged during that policy change.

## New skills, candidates for evaluation

- `retro`: review actual sessions for improvements to instructions, checks,
  navigation, and tooling. Evaluate whether its recommendations are specific
  and useful before adopting it. Changes require the owner's selection.
- `pr`: evaluate its visual summaries, concrete evidence, and discussion of
  reversibility and impact. Preserve project PR templates and attribution,
  including the upstream `CREDITS.md`. Automatic invocation requires opt-in.
- `implement-spec`: a candidate for whole-spec implementation. Its tracker
  setup, orchestration, PR lifecycle, and cleanup need separate evaluation.

If selected for evaluation, put candidates under `skills/experimental/` and
install them individually. Moving one to the stable set is a separate decision.

## Source maintenance

Use `$maintain-skill-sources` to compare the canonical stable directories against
upstream. Refreshes replace those directories and update `skills/sources.tsv`.
