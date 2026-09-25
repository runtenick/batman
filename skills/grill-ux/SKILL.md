---
name: grill-ux
description: Interview the user to agree on a feature's user journey, constraints, and three UI directions before prototyping.
disable-model-invocation: true
---

# Grill UX

Turn a vague feature idea into a shared design for three UI prototypes. Interview only. Do not build prototypes or write documents unless requested.

## 1. Ground the interview

Read the conversation and inspect the relevant page, nearby components, and project UI instructions or design skills. Find facts yourself; ask the user for decisions. Follow existing design conventions unless the user explicitly wants broader exploration. Do not delegate unless requested.

## 2. Build the decision tree

Organize unresolved decisions by dependency:

```text
User + situation + current difficulty
└── Task + intended benefit
    ├── Core journey: entry → choices → result
    │   └── Three interaction directions for the same outcome
    ├── App placement + design constraints
    └── Main uncertainty for team discussion
        └── Minimum journey and data needed to explore it
```

Adapt the tree to the feature. Reuse settled answers. Mark each decision as settled, open, or deliberately left for prototype exploration.

Challenge whether the feature addresses the user's need, briefly. Treat unsupported claims about user behavior as assumptions. Do not expand into product strategy, backend design, or final MVP definition.

## 3. Ask the current frontier

The frontier contains open decisions whose prerequisites are settled. Ask those together in a round; defer dependent questions until their prerequisites are answered.

Use this format, continuing question numbers across rounds:

```text
Q1 — Question title
<Decision to make, with concrete options and their tradeoffs.>

Recommendation: <Your recommended answer and why.>

---

Q2 — Question title
<Next independent decision.>

Recommendation: <Your recommended answer and why.>
```

Wait for answers. Update the tree, then ask the new frontier. Do not repeat settled questions or ask the user to decide things the prototypes should reveal.

Propose concrete interaction directions during the interview. For scheduling, these might be a guided flow, direct calendar manipulation, and an adjustable recommendation. Hold the user outcome constant; vary how the user reaches it. Explore different feature scopes only when explicitly agreed.

Bound the first build to one complete core journey per variant. Add another state or path only if it could change the team's decision. Leave room for later requests to extend the prototypes.

## 4. Confirm and stop

Stop questioning when the remaining open decisions can be explored through prototypes. Summarize in the conversation:

```text
User and situation: ...
Task and intended benefit: ...
Core journey: ...
App placement and design constraints: ...
Directions A / B / C: ...
Question the prototypes should help the team discuss: ...
In scope / deferred: ...
Assumptions still untested: ...
```

Ask the user to confirm or correct this shared understanding. Resolve corrections, then stop. Team agreement does not validate user behavior.

Keep the summary in the conversation for a separate `ui-prototype` invocation, including after compaction. Create no document by default. Offer a short recap document only when useful for sharing or returning later, and write it only if requested. Do not invoke `ui-prototype` automatically.
