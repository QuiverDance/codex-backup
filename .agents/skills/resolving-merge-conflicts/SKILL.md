---
name: resolving-merge-conflicts
description: "Use when you need to resolve an in-progress git merge/rebase conflict."
---

1. Inspect merge/rebase state, history, conflicts, and the starting index and worktree. Record unrelated pre-existing changes.

2. Read the primary sources for both intents: commits and applicable accepted requirements, PRs, or issues.

3. Resolve each conflict to preserve both intents where compatible. Use the accepted merge goal for technical choices. If resolution requires a new material product decision, ask and continue independent conflicts. Do not invent behavior. Honor an explicit abort request; otherwise work toward completing the operation.

4. Run affected and repository-required checks and fix regressions introduced by the resolution. Broaden verification when the merge's reach or evidence warrants it.

5. Stage only files required for this merge/rebase, preserving unrelated user changes. Inspect the index before completing the merge or continuing the rebase. Continue through remaining commits when authorized, then read back the final status and report any unresolved limits.
