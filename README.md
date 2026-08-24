# GH200 Codex conversation backup

This orphan branch contains only the Codex conversation created on the current
GH200 server in session `01a032b1-ad6d-7bc2-a677-1004af67a370`.

Contents:

- `.codex/session_parts/01a032b1-ad6d-7bc2-a677-1004af67a370/`:
  chunked raw Codex rollout required to restore the original thread
- `.codex/session_index.jsonl`: index entry for this thread only
- `.codex/conversations/gh200/visible-transcript.md`: user/assistant-visible
  conversation from this server
- `.codex/memories/rollout_summaries/2026-08-24-gh200-kv-compression-experiment-handoff.md`:
  experiment state, verified results, paths, environment findings, and the exact
  next experiment
- `scripts/export_visible_codex_session.py`: public-safe transcript exporter
- `scripts/restore_codex_session.sh`: restores the raw session into a fresh
  Codex home

No other server memories, skills, or sessions are included. Authentication,
SQLite databases, and caches remain excluded. The raw rollout does include this
thread's developer records, reasoning records, and tool payloads so the original
thread can be reconstructed.

## Continue on a fresh server

```bash
git clone --branch gh200 --single-branch \
  https://github.com/QuiverDance/codex-backup.git
cd codex-backup
bash scripts/restore_codex_session.sh
```

Close VS Code/Codex before running the restore script, then sign in and reopen
VS Code. Codex will rebuild its local state database from the restored rollout.
If workspace filtering hides the thread, open `/home/ubuntu` or run
`codex resume --all 01a032b1-ad6d-7bc2-a677-1004af67a370` once.
