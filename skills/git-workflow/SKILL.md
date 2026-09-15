---
name: git-workflow
description: Apply personal Git standards when considering commits, pushes, branch changes, or other operations that change repository state.
disable-model-invocation: true
---

# Git workflow

Use this skill whenever you consider a Git operation that changes repository state. Read-only inspection does not need this workflow.

## Ground rules

- Run read-only commands such as `status`, `diff`, `log`, `show`, and `blame` without notice or approval. `fetch` also needs no approval.
- Stage changes for the current task without approval. Preserve anything the user already staged, exclude unrelated changes, and inspect the staged diff before proposing a commit.
- Ask for explicit approval before any other operation that changes branches, commits, tags, worktrees, local history, or remote state. Explain the exact operation and its effect. If either changes, ask again.
- One approval may cover a connected sequence such as creating and switching to a branch. A commit and a push always require separate approvals.
- Repository instructions may add stricter rules or narrower conventions. They do not remove this skill's approval requirements.
- Keep each commit focused on one coherent change. Leave unrelated changes untouched.

## Commit

Decide when a focused change is ready to commit. Use Conventional Commits for every message:

```txt
<type>[optional scope]: <description>
```

Choose the narrowest accurate lowercase type. Prefer `feat`, `fix`, `docs`, `refactor`, `test`, `build`, `ci`, `chore`, `perf`, `style`, or `revert`. Use another type only when the repository defines it. Follow repository-specific scope rules within this format.

Write a short imperative subject without a trailing period. Add a body only when the reason or tradeoff is not clear from the diff. Mark a breaking change with `!` before the colon or a `BREAKING CHANGE:` footer. Do not add AI or agent attribution.

Before every commit, show the exact message and a compact summary of the staged files and changes. Group a large file list instead of cluttering the response. Mention a concern only when one exists. Ask for approval of that exact proposal. A general request to finish the work is not commit approval.

Approve and create one commit at a time. If the staged changes or message changes after approval, ask again. If the user rejects the commit, leave the changes staged and say so.

## Push

You may offer to push after a successful commit. State the source branch, remote, and destination branch, then ask for separate approval.

If a push fails, report the reason. Do not pull, rebase, or retry with force without new approval. Never propose a force-push unless the user requested it. Explain which remote history it would replace.

## Other changes

Get approval before creating or switching branches, pulling, merging, rebasing, stashing, tagging, amending, reverting, cherry-picking, resetting, cleaning, or changing worktrees. Do not perform these operations just because they might help. Propose one only when the task calls for it.
