# Original GH200 conversation transcript

This directory contains the public-safe conversation export for the original
GH200 Codex session `01a032b1-ad6d-7bc2-a677-1004af67a370`.

- `visible-transcript.md`: all stored user/assistant messages from the session
- `../../memories/rollout_summaries/2026-08-24-gh200-kv-compression-experiment-handoff.md`:
  compact operational state, results, and the exact next experiment

The repository-level snapshot contains the raw rollout JSONL and complete
session index for all six local Codex conversations found at backup time. This
directory remains a readable transcript of the original experiment thread;
see the root `README.md` and `.codex/session_manifest.tsv` for the complete
snapshot. Authentication files, SQLite state, and caches are not committed.

The following steps are for a future restore on a fresh server only. They are
not part of creating the current backup:

```bash
git clone --branch gh200 https://github.com/QuiverDance/codex-backup.git
cd codex-backup
bash scripts/restore_codex_session.sh
```

Run the restore while VS Code/Codex is closed, then reopen VS Code after signing
in. Verify that Codex imports the backed-up threads into its local thread
database:

```bash
codex resume --all
```

After the session list appears, press `Ctrl-C`. In VS Code, open the Command
Palette, run `Developer: Reload Window`, and reopen the Codex sidebar. This
reload is relevant only after a future restore; no panel restart is performed
while making the backup.

For the full recovery and remote-agent safety notes, see the repository root
`README.md`.
