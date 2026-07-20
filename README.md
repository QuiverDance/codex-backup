# Codex backup

This repository contains the portable, user-maintained parts of the local Codex setup:

- `.codex/AGENTS.md`: personal Codex instructions
- `.codex/memories/raw_memories.md` and `.codex/memories/rollout_summaries/`: compact work summaries and reusable project knowledge, not full chat transcripts
- `.agents/skills/`: installed engineering skills
- `.agents/.skill-lock.json`: skill installation metadata

Authentication, sessions, logs, caches, databases, attachments, generated memory instructions, bundled system skills, and default Codex settings are intentionally excluded.

To restore these files into a fresh environment, copy them back to the same paths after Codex has been installed.
