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

## Restore and refresh VS Code Codex

Prefer to close VS Code/Codex before restoring so the app server starts with a
fresh view of the local session index.

```bash
git clone --branch gh200 --single-branch \
  https://github.com/QuiverDance/codex-backup.git
cd codex-backup
bash scripts/restore_codex_session.sh
```

The script verifies the reconstructed rollout checksum, backs up an existing
session file and `session_index.jsonl`, and merges this thread without changing
authentication, configuration, caches, or unrelated sessions.

After the script succeeds:

1. Sign in and reopen VS Code with `/home/ubuntu` as the workspace.
2. Force Codex to import and recognize the restored thread once:

   ```bash
   codex resume --all 01a032b1-ad6d-7bc2-a677-1004af67a370
   ```

   Wait until the earlier transcript is displayed, then press `Ctrl-C` to exit
   the verification TUI. The expected thread name is `KV 압축 성능 재실험`.
3. Refresh the VS Code Codex conversation list. Open the Command Palette and
   run `Developer: Reload Window`, then reopen the Codex sidebar.

Step 3 is required when the restore ran while VS Code/Codex was already open:
the active Codex panel can retain the pre-restore thread list even after the
rollout and local state database contain the restored thread. Merely running
`codex resume` in a separate terminal does not refresh that panel cache.

For a remote recovery performed from inside Codex, the recovery agent must
finish and persist its current response first. It may then restart only the
remote VS Code extension host that owns the OpenAI Codex `app-server`; it must
not kill the whole VS Code server. The interactive `Developer: Reload Window`
command is preferred whenever the user can access the VS Code UI.

### Remote/headless panel restart

Use this fallback only when the user explicitly asks the recovery agent to
perform the panel restart and cannot run `Developer: Reload Window`:

1. Verify the restored session with the `codex resume --all ...` command above
   and exit the verification TUI.
2. Locate the exact OpenAI Codex `app-server` process whose executable is under
   the active `openai.chatgpt-*` VS Code extension. Resolve its immediate parent
   and verify that parent is the remote VS Code extension host under
   `.vscode-server`; do not use a broad `pkill` pattern.
3. Finish the recovery turn and persist the response before restarting
   anything. Schedule a targeted `SIGTERM` to that verified extension-host PID
   after a short delay (10-15 seconds), allowing this response to reach the
   user. VS Code should recreate the extension host and reconnect the panel.
4. Never terminate the VS Code server, remote agent, unrelated extension hosts,
   or every `node`/`codex` process. After reconnection, reopen the Codex sidebar
   and confirm that `KV 압축 성능 재실험` is listed.

The official Codex CLI command reference for resuming saved chats is at
<https://developers.openai.com/codex/cli/reference>.
