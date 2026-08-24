# GH200 Codex conversation backup

This orphan branch contains only the Codex conversation created on the current
GH200 server in session `01a032b1-ad6d-7bc2-a677-1004af67a370`.

Contents:

- `.codex/conversations/gh200/visible-transcript.md`: user/assistant-visible
  conversation from this server
- `.codex/memories/rollout_summaries/2026-08-24-gh200-kv-compression-experiment-handoff.md`:
  experiment state, verified results, paths, environment findings, and the exact
  next experiment
- `scripts/export_visible_codex_session.py`: public-safe transcript exporter

No other server memories, skills, sessions, authentication, tool payloads,
reasoning records, SQLite databases, caches, or raw Codex rollout files are
included.

## Continue on a fresh server

```bash
git clone --branch gh200 --single-branch \
  https://github.com/QuiverDance/codex-backup.git
```

Start Codex in the restored project and ask it to read the handoff and visible
transcript before acting. The handoff contains the continuation prompt and
preflight checks.
