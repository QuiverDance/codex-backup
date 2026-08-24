# GH200 conversation backup

This directory contains the public-safe conversation export for Codex session
`01a032b1-ad6d-7bc2-a677-1004af67a370`.

- `visible-transcript.md`: all stored user/assistant messages from the session
- `../../memories/rollout_summaries/2026-08-24-gh200-kv-compression-experiment-handoff.md`:
  compact operational state, results, and the exact next experiment

Raw Codex rollout JSONL, authentication files, developer instructions,
reasoning records, tool payloads, SQLite state, and caches are deliberately not
committed because this repository is public.

To continue on a fresh server:

```bash
git clone --branch gh200 https://github.com/QuiverDance/codex-backup.git
```

Then start Codex in the restored project and ask it to read the handoff and
visible transcript before taking action.  This is a portable context handoff;
it is not a byte-for-byte restoration of the original Codex UI thread.
