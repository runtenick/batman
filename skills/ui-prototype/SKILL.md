---
name: ui-prototype
description: Build three throwaway interactive UI alternatives from an agreed design, using feature-scoped mock data for team discussion.
disable-model-invocation: true
---

# UI prototype

Build three inexpensive, interactive alternatives that help the team discuss a feature before defining and implementing the MVP. Work from the agreed design in the conversation, normally established with `grill-ux`, or an equivalent direction supplied by the user.

This is a building skill. Do not run another interview or require a brief document. Read the available context and make small implementation choices yourself. If the task or intended outcome is missing entirely, state that the design context is missing and stop without inventing a feature or starting a questionnaire.

## Use the app's context

Inspect the relevant page, components, and applicable UI guidance or design skills. Follow the project's design language and conventions unless the user explicitly asks to explore beyond them. Prefer the natural host page or flow. For a new UI, create only the surrounding context needed to understand the task, using the project's conventions.

Keep prototype work on a throwaway branch, following the repository's Git rules and any required permissions. Preserve unrelated work. Use the existing development setup and make the prototype easy to reach. No separate app, mock server, or new framework is needed by default.

## Mock only the feature

Replace the data the feature needs with small, editable fixtures. Simulate its mutations in local memory so the user can complete the intended journey without changing live data. Keep existing login, navigation, and unrelated application dependencies as they are.

For example, on a page that loads documents, substitute the relevant document data and simulate the document interactions being explored. Do not recreate the login flow or mock the rest of the app. Backend independence is not a requirement.

Use plausible content and comparable starting scenarios across the variants. Add an empty, conflicting, or other awkward case only when it helps answer the design question. A reload or simple reset should restore the starting state; build no scenario framework or persistence layer.

## Build three interaction alternatives

Hold the intended user outcome constant. Give each variant a distinct interaction approach, information hierarchy, or primary action. Three cosmetic variations do not explore enough. Respect any directions already agreed during grilling and choose remaining details yourself.

Build one complete core journey per variant: enter the feature, make the meaningful choices, and see the result. Support revision or undo when relevant to that journey. Keep all three usable enough to compare. Additional journeys and states can follow when the user asks.

Reuse existing components where helpful, but keep the alternatives free to differ structurally. Avoid abstractions that make one variant expensive to change. Spend effort on understandable content, feedback, and interaction, and follow the project's accessibility guidance.

Provide a small variant switcher and a direct way to open each alternative. A URL parameter such as `?variant=A` is a useful default when it fits the app. Keep the switcher distinct from the UI under discussion and avoid losing the ability to complete the journey when switching variants.

Name each alternative by its interaction approach and briefly explain the tradeoff it explores. Keep this rationale in the handoff or prototype controls rather than filling the feature UI with implementation notes.

## Keep the experiment cheap

Use disposable code. Add no automated test suite, speculative architecture, backend contracts, or error handling unrelated to the journey being explored. Follow required project checks and do a quick walkthrough of the core journey in each variant using available tools. Report any interaction you could not verify.

Do not delegate unless the user asks for it. Do not expand the scope to make the prototype production-ready.

## Hand over for discussion

Give the run command, entry URL and variant links, the branch name, and a short explanation of each alternative's tradeoff. Identify relevant mocked behavior and remaining assumptions so the team knows what it is reviewing. Existing app prerequisites can remain; mention those needed to open the prototype.

Leave the alternatives available on the throwaway branch, following repository rules for any commits or pushes. Do not automatically select a winner, merge it, or implement the MVP. The user can request revisions here, then take the branch and feedback notes into a new standard grilling session to determine the actual MVP.

The prototype supports team alignment. User analytics and feedback after release can inform whether the eventual feature delivers the expected benefit; the prototype itself does not establish that.

## Sources

Adapted from Matt Pocock's [prototype skill](https://github.com/mattpocock/skills/tree/959a8e9f1edc3adbe2f7e3054bb6fbefa6696260/skills/engineering/prototype), especially its structural alternatives, switcher, and disposable implementation. Informed by Jeff Gothelf's [Lean UX Canvas](https://jeffgothelf.com/blog/how-to-use-the-lean-ux-canvas/), particularly explicit assumptions and doing the least work needed for the next useful experiment.
