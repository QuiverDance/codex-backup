---
name: implement
description: "Implement a piece of work based on a PRD or set of issues."
---

Implement the accepted work described by the user, PRD, or issues. Record the starting working-tree state and task file scope so unrelated changes remain separate.

Use `tdd` for explicit test-first requests and behavior where regression coverage is useful. Reuse agreed or obvious existing interfaces; ask only about material unresolved contracts. Complete each slice through the accepted intended flow.

Run affected tests, relevant type checks, and repository-required checks. Run the full suite when change reach, risk, failures, or unresolved concerns warrant it; do not repeat passing checks without a reason.

Before committing, use `code-review` on the actual in-scope staged, unstaged, and untracked changes, with the accepted requirements and starting baseline. Correct actionable findings and rerun affected verification.

Commit only this task's work to the current branch when the user's instructions permit committing. Honor requests to leave changes uncommitted. A local commit does not authorize pushing, publishing, or deployment.
