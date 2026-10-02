---
name: ui-prototype
description: Build three interactive UI alternatives from an agreed design, using minimal feature-scoped mocks on a throwaway branch.
disable-model-invocation: true
---

# UI prototype

Build three disposable alternatives for team discussion. Use the agreed design from the conversation or supplied context. Do not interview the user or require a design document. Decide small implementation details yourself. If the task and intended outcome are absent, report the missing context and stop.

## 1. Locate the feature

Read the relevant code and project UI instructions or design skills. Follow the existing component library, visual language, and accessibility guidance unless broader exploration was explicitly requested.

- Existing page or flow: mount the alternatives in their natural location, preserving the surrounding app.
- New UI with no suitable host: add a prototype page using the project's routing conventions and only the context needed for the task.

Use the existing development setup. Work on a throwaway branch under the repository's Git rules and required permissions. Preserve unrelated work. Do not delegate unless requested.

## 2. Choose three distinct approaches

Use the agreed directions. Fill any remaining gaps with approaches that differ in interaction, information hierarchy, or primary action. Keep the intended user outcome constant unless scope differences were explicitly agreed.

State the build plan briefly, then proceed without another approval round:

```text
Task: <what the user will accomplish>
Host: <page or flow>
A: <approach and tradeoff>
B: <approach and tradeoff>
C: <approach and tradeoff>
```

If two alternatives differ only in styling, replace one with a different interaction approach before building.

## 3. Mock the feature's inputs and actions

- Substitute small, editable fixtures for the data this feature uses.
- Simulate its mutations in local memory. Do not send prototype actions to live mutation endpoints.
- Keep existing authentication, navigation, and unrelated dependencies. Do not mock the whole app or require backend independence.
- Start each variant from comparable, plausible data. Add awkward cases only when relevant to the exploration.
- Restore the starting state with a reload or simple reset. Add no persistence or mock infrastructure.

Example: for a document interaction, replace the page's relevant document data and simulate its edits. Leave the route and login flow in place.

## 4. Build the core journeys

Implement each variant as a separately editable component, such as `VariantA`, `VariantB`, and `VariantC`. Reuse existing UI components and fixtures; avoid a shared layout that forces the alternatives to behave alike.

Make one journey work end to end in each variant: enter, make the meaningful choices, see the result. Include revision or undo where the task needs it. Wire the controls on that journey; do not stop at static screens.

Spend effort on interaction, content, hierarchy, and feedback. Add no automated test suite, backend contracts, speculative abstractions, or error handling unrelated to the journey. Extend beyond the agreed exploration only when requested.

## 5. Make comparison easy

Default to `?variant=A`, `?variant=B`, and `?variant=C` on the host route. Use the framework's router and preserve unrelated URL parameters.

Add a small floating switcher with a labeled button for each alternative. Show the active variant and keep the switcher visually distinct from the feature. Switching should open the selected variant at its starting state, using a fresh copy of the fixtures. A reload should retain the selected variant and reset its data.

Use an equivalent direct-link mechanism if query parameters do not fit the app. Keep comparison controls simple; build no reusable prototype framework.

## 6. Check and hand over

Run required project checks and walk through the core journey in each variant using available tools. Check switching and reset behavior. Report anything you could not verify; do not add a test suite for disposable code.

Return:

```text
Run: <command and any existing app prerequisites>
Open: <entry URL and links for A / B / C>
Branch: <throwaway branch>
A / B / C: <one-line interaction tradeoff for each>
Mocked: <relevant data and actions>
Still assumed: <what team review or later user evidence must resolve>
Verification: <what was checked and any limits>
```

Leave all alternatives available for review. Follow repository rules for commits and pushes. Do not choose a winner, merge the prototypes, or implement the MVP. Revisions can happen on request; MVP definition belongs to a later standard grilling session using the branch and team feedback.
