---
name: grill-ux
description: Interview the user to turn a vague feature idea into a shared UX design for exploring interactive UI alternatives with the team.
disable-model-invocation: true
---

# Grill UX

Reach a shared understanding of what to explore before building UI prototypes. The usual audience is the technical team and product owner. The goal is to make a feature concrete enough for discussion; agreement within the team is not evidence that users will benefit.

## Ground the discussion

Use the conversation and inspect the relevant app before asking about facts you can find yourself. Look for the feature's likely home, nearby interactions, components, and applicable project UI guidance or design skills. Respect those conventions unless the user explicitly wants broader exploration. Keep research proportional to the feature. Do not introduce delegation unless the user asks for it.

Establish enough of the following to make useful alternatives:

- Who is doing what, in which situation, and what currently gets in their way?
- What benefit should the feature provide? Briefly challenge whether the proposed feature addresses that need, without turning the interview into a product strategy workshop.
- Where does the interaction start, what decisions does the user make, and what result should they reach?
- Where does it fit in the current app, or what surrounding context does a new UI need?
- Which assumptions or interaction choices would be most useful for the team to examine through prototypes?
- What belongs in the initial exploration, and what can wait?

Use Lean UX's focus on outcomes, explicit assumptions, and the smallest useful experiment. Treat claims without evidence as assumptions. A useful framing is: "We believe this interaction will help this user achieve this benefit. The prototypes should help us examine this uncertainty." Use plain language rather than requiring a canvas or formal hypothesis template.

## Interview in rounds

Map the decisions and their dependencies. In each round, ask the unresolved questions whose prerequisites are already settled. Number each question, explain concrete options or tradeoffs, and give a recommended answer. Wait for the user's answers before asking dependent questions. Carry settled answers forward.

Suggest interaction approaches as you go. Help the user reason with a concrete scenario rather than requiring them to invent the design in words. For example, resolving a scheduling conflict might use a guided flow, direct calendar manipulation, or a recommendation the user can adjust.

Keep the intended user outcome constant across the three alternatives. Let them differ in interaction approach, information hierarchy, or how the user makes a decision. If exploring different feature scopes would help, agree that explicitly and identify the differences.

Leave questions that the prototypes should answer open. Do not resolve every detail, design backend contracts, or define the final MVP before the team has seen the alternatives. The initial build should cover one complete core journey per variant; the user can request more depth afterward.

## Reach shared understanding

Stop when the user, task, intended benefit, app context, exploration boundaries, and main uncertainty are clear enough to build. Summarize the agreed design and the interaction directions in the conversation, including assumptions still open to exploration. Ask the user to confirm or correct that understanding.

Produce no document by default. The usual next step is a separate `ui-prototype` invocation in the same session, possibly after compaction. Keep the conversational summary sufficient to carry the decisions forward. If a written record would help with sharing or returning later, offer a short recap document and write it only if requested.

End with the shared understanding. Do not start building automatically. Later MVP definition belongs to a separate standard grilling session using the prototype branch and team feedback.

## Sources

Adapted from Matt Pocock's [grill-me](https://github.com/mattpocock/skills), through Batman's `grilling` interview pattern, and informed by Jeff Gothelf's [Lean UX Canvas](https://jeffgothelf.com/blog/how-to-use-the-lean-ux-canvas/). This skill is self-contained; it does not load the general grilling workflow.
