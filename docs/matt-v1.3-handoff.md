# Matt v1.3 follow-up

This handoff records the October 5, 2026 review of
[Matt's v1.3 changelog](https://www.aihero.dev/skills/skills-changelog-v13-implement-spec-pr-retro-and-glossary-md).
It authorizes no further changes. Review each item separately with the owner.

## Adopted glossary convention

Batman now uses `GLOSSARY.md` and `GLOSSARY-MAP.md` in the active
`domain-modeling` and `tdd` skills. The root glossary is `GLOSSARY.md`, and the
domain-modeling template is `GLOSSARY-FORMAT.md`. Glossary content and the
skills' manual-only invocation defaults are preserved.

Other projects using these skills need their old glossary filenames and
references migrated together. Confirm that an existing `CONTEXT.md` is a domain
glossary before renaming it, and check for an existing `GLOSSARY.md` to avoid
overwriting or splitting the vocabulary.

## Dependency loading, pending review

`skills/dev-workflow/implement/SKILL.md` still says `Use /tdd`.
Matt's release explicitly loads dependencies through a Skill tool. Batman's
`grill-me` and `grill-with-docs` already use sibling file references instead.

Review whether `implement` should explicitly read and follow
`../tdd/SKILL.md`, and whether that should become the common convention for
included dependencies across Batman's supported agents. Keep model invocation
and delegation under the owner's control. No dependency instructions were
changed in the glossary migration.

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
