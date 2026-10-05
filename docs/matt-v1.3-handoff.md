# Matt v1.3 follow-up

This handoff records the October 5, 2026 review of
[Matt's v1.3 changelog](https://www.aihero.dev/skills/skills-changelog-v13-implement-spec-pr-retro-and-glossary-md).
It authorizes no further changes. Review each item separately with the owner.

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

Stable skills now inherit their source's default invocability, including the
Matt-derived UX adaptations. Skills without a source are manual by default.
Fresh installations use these defaults; existing local invocation settings are
preserved. Experimental projections also inherit source defaults after explicit
addition. Model choice and delegation remain under the owner's control.

## Implementation close-out, pending review

Upstream `implement` ends with code review and a commit. Batman's version ends
with verification and prohibits commits unless the owner explicitly requests
one. Preserve that commit boundary.

Decide separately whether implementation should automatically include review.
Batman's current `code-review` uses `git diff <fixed-point>...HEAD`, which omits
uncommitted changes. Before adding a review step, define how it should include
staged, unstaged, and new files, how the comparison point is selected, and how
existing unrelated edits are excluded. Keep the Standards and Spec review axes
separate, and preserve the explicit authorization requirement for delegation.

## New skills, candidates for evaluation

- `retro`: review actual sessions for improvements to instructions, checks,
  navigation, and tooling. Evaluate whether its recommendations are specific
  and useful before adopting it. Changes require the owner's selection.
- `pr`: evaluate its visual summaries, concrete evidence, and discussion of
  reversibility and impact. Preserve project PR templates and attribution,
  including the upstream `CREDITS.md`. Automatic invocation requires opt-in.
- `implement-spec`: defer until the owner wants whole-spec orchestration with
  parallel agents, worktrees, and an integration branch. Its tracker setup,
  commits, PR lifecycle, and cleanup need separate review against Batman's rules.

If selected for evaluation, put each unchanged upstream directory under
`skills/experimental/`, pin its commit and hash in `sources.tsv`, and keep
installation explicit. Promotion or personal adaptation is a separate decision.

## Source maintenance

The twelve source snapshots added October 5 already include v1.3. The existing
`implement` and `writing-for-agents` snapshots retain their October 2 pins.
Use `$maintain-skill-sources` for a check before deciding whether to refresh
those snapshots. Snapshot maintenance does not update active personal skills.
