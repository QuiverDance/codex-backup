# Codex backup

This repository contains the portable, user-maintained parts of the local Codex setup:

- `.codex/AGENTS.md`: personal Codex instructions
- `.codex/memories/raw_memories.md` and `.codex/memories/rollout_summaries/`: compact work summaries and reusable project knowledge, not full chat transcripts
- `.agents/skills/`: installed engineering skills
- `.agents/.skill-lock.json`: skill installation metadata

Authentication, sessions, logs, caches, databases, attachments, generated memory instructions, bundled system skills, and default Codex settings are intentionally excluded.

## setup branch

This branch backs up the current global instructions and 22 personal skills.
System skills and plugin caches are not managed here. Existing memories,
`find-skills`, and `.agents/.skill-lock.json` are preserved from `main`; they are
historical files, not part of the refreshed local snapshot. The installer lock
does not describe the locally edited versions of the skills.

### Restore

Back up existing local files first. Copy `.codex/AGENTS.md` to your Codex home's
`AGENTS.md`, and each personal folder in `.agents/skills/` to its `skills/` folder.
For the source Windows setup, Codex home is `$HOME/.codex`. Skip the historical
`find-skills` folder unless explicitly wanted. Preserve the local `.system`
folder and plugins. Restore memories separately only if wanted.

### Update

1. Check out `setup` and pull with `git pull --ff-only`.
2. Copy the current global instructions into `.codex/AGENTS.md`.
3. Copy personal skill folders into `.agents/skills/`, including references,
   assets, scripts, and `agents/openai.yaml`. Exclude `.system`, plugin caches,
   temporary files, and bytecode. Review obsolete backup files separately.
4. Review `git status` and `git diff`, stage only intended changes, commit,
   and push to `setup`.

Updates are explicit commits; no scheduled synchronization is configured.
