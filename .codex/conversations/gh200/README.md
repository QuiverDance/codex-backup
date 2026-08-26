# GH200 conversation backup

This directory contains the public-safe conversation export for Codex session
`01a032b1-ad6d-7bc2-a677-1004af67a370`.

- `visible-transcript.md`: all stored user/assistant messages from the session
- `../../memories/rollout_summaries/2026-08-24-gh200-kv-compression-experiment-handoff.md`:
  compact operational state, results, and the exact next experiment

The repository also contains the raw rollout JSONL and the single matching
session-index entry so the original VS Code Codex thread can be restored.
Authentication files, SQLite state, and caches are not committed.

To continue on a fresh server:

```bash
git clone --branch gh200 https://github.com/QuiverDance/codex-backup.git
cd codex-backup
bash scripts/restore_codex_session.sh
```

Run the restore while VS Code/Codex is closed, then reopen VS Code after signing
in. Verify that Codex imports the raw rollout into its local thread database:

```bash
codex resume --all 01a032b1-ad6d-7bc2-a677-1004af67a370
```

After the earlier transcript appears, press `Ctrl-C`. In VS Code, open the
Command Palette, run `Developer: Reload Window`, and reopen the Codex sidebar.
This final reload is required if the panel was open during restoration because
it can cache the old conversation list. The expected restored thread name is
`KV 압축 성능 재실험`.

For the full recovery and remote-agent safety notes, see the repository root
`README.md`.
