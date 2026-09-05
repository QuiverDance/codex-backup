---
name: ask-matt
description: Ask which skill or flow fits your situation. A router over the skills in this repo.
---

# Ask Matt

Recommend the shortest useful route for the user's situation. Skill names below are routing suggestions, not mandatory phases. Respect each skill's invocation policy and the user's selected scope. Do not add an interview, publication, or new task merely because it appears in a route.

- An unclear plan the user wants to sharpen: `grill-me`, or `grill-with-docs` when they want repository domain records. Both use `grilling`.
- A design question needing runnable evidence: `prototype`, in the current task unless a separate task is requested.
- An accepted plan needing documentation: `to-prd`; a larger accepted plan needing independent work items: `to-issues`. Preserve publication and review checkpoints.
- Ready implementation: `implement`, with meaningful `tdd` when appropriate and `code-review` over actual changes before committing. A small concrete request can be completed directly.
- A branch, PR, or working-tree review: `code-review` with the matching target.
- A hard or unclear bug: `diagnosing-bugs`, improving reproduction and investigating evidence together. A simple localized bug need not enter a long diagnostic workflow.
- Incoming reports: `triage` using the existing tracker configuration.
- Requested architecture survey: `improve-codebase-architecture`; chosen interface design: `codebase-design`.
- Domain terminology or architectural records: `domain-modeling`.
- Reading and evidence gathering: `research`, with a sub-agent only when useful independent work can run alongside it.
- Learning: `teach`. Skill authoring: `writing-great-skills`.
- Missing configuration actually needed by the selected workflow: `setup-matt-pocock-skills`. Existing configuration is sufficient; setup is not a universal prerequisite.

## Continuity

Keep accepted decisions and outstanding work available through normal compaction. Continue the same task without a fixed token cutoff or mandatory fresh session. Use `handoff` when the user wants a portable record or transfer; creating or forking a task requires the user's request. A prototype or an issue boundary alone does not require clearing context.
