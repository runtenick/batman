# Tips for your environment with coding agents

## Minimize invisible instructions

As I added more and more skills to my workflow, it became increasingly difficult to keep track of every instruction my agent is being given.
Meaning, sometimes the agent will do something you will assume stupid or incorrect, but its following an instruction from a skill YOU gave it.

It is hard to keep track of all the instructions scattered across different skills. And you end up with __invisible instructions__.

This is why I aim to:
- minimize the number of skills I have as much as possible
- be aware of the content of each skill
- regularly review and update skills to ensure they align with my current workflow
- if a skill is not useful or relevant anymore, remove it
- prioritize manual invocation workflows, where you are aware of what you are triggering, instead of relying on automatic triggers that might execute when you did not intend them to.

## Maintaining someone's skill

When you borrow a skill from someone, you might end up tweaking it a bit, for your own needs. But what happens, if the source skill is updated by the original owner ?
Now you might want to update your version of the skill to incorporate the latest changes from the original owner, while still keeping your custom modifications intact.
This sounds simple, but as your number of borrowed skills and custom changes grow, it might become hard to maintain them (or expensive if you rely on your agents to do it for you).

To solve this I try to:
- avoid changing the original skill directly. If there are updates from the original, you can simply pull them.
- if I have to change it, I create a new file and most importantly __rename the skills__. For example `/implement` becomes `/implement-at-work`. Its easier to treat it as a different skill that you own and maintain.
- prefer project-scoped instructions to override behavior from skills instead of changing them. For example for a specific project you might want to set instructions such as "do not commit" or "do not use subagents."