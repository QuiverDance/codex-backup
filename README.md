# GH200 Codex conversation backup

This orphan branch contains a point-in-time backup of active local Codex
conversations found under `sessions/` on the GH200 server. Deleted conversations
under `archived_sessions/` are excluded. The current snapshot's session count
and exact export time are recorded in `.codex/session_manifest.tsv`.

## Snapshot contents

- `.codex/session_manifest.tsv`: session IDs, original relative paths, SHA-256
  checksums, byte sizes, and part counts
- `.codex/session_parts/<session-id>/`: chunked raw rollout JSONL for every
  conversation
- `.codex/session_index.jsonl`: the active-session subset of the saved-session
  index at snapshot time, preserving duplicate rename entries for active IDs
- `.codex/conversations/gh200/visible-transcript.md`: user/assistant-visible
  transcript for the original GH200 KV experiment thread
- `.codex/memories/rollout_summaries/2026-08-24-gh200-kv-compression-experiment-handoff.md`:
  experiment state, verified results, paths, environment findings, and the exact
  next experiment
- `scripts/export_all_codex_sessions.sh`: creates or refreshes the all-session
  snapshot
- `scripts/export_visible_codex_session.py`: public-safe transcript exporter
- `scripts/restore_codex_session.sh`: restores every backed-up session later on
  a fresh server

Authentication, configuration, SQLite databases, caches, skills, and unrelated
runtime files are excluded. The raw rollouts do include each thread's developer
records, reasoning records, and tool payloads so the original threads can be
reconstructed. A high-confidence token/private-key pattern scan reported no
matches before this snapshot was committed, but this remains a public raw
conversation backup and should be treated accordingly.

## Sessions in this snapshot

The exact active session IDs and paths are listed in
`.codex/session_manifest.tsv`; their saved names are in
`.codex/session_index.jsonl`. Deleted or archived session IDs are not included.

## Refresh the backup

This is the operation to run when backing up the current server:

```bash
bash scripts/export_all_codex_sessions.sh
```

The exporter copies all complete rollout JSONL records into an isolated
snapshot, validates each JSONL and session ID, writes fixed-size parts, records
checksums and sizes in the manifest, and replaces the repository copy of the
session index. It does not modify the live Codex sessions and does not copy
`auth.json`, configuration, databases, caches, or skills.

Do not run the restore script or restart VS Code/Codex while creating a backup.
Because a live conversation can continue appending after the copy, the manifest
timestamp defines the exact backup boundary.

## Restore later on a fresh server

The steps in this section are for a future restore only, not for creating the
backup above. Close VS Code/Codex on the destination before restoring.

```bash
git clone --branch gh200 --single-branch \
  https://github.com/QuiverDance/codex-backup.git
cd codex-backup
bash scripts/restore_codex_session.sh
```

The restore script verifies every reconstructed rollout against the manifest,
backs up colliding destination session files and `session_index.jsonl`, and
merges all backed-up threads without changing authentication, configuration, caches,
or unrelated sessions.

After the restore succeeds on the destination:

1. Sign in and reopen VS Code with `/home/ubuntu` as the workspace.
2. Force Codex to import and recognize the restored threads once:

   ```bash
   codex resume --all
   ```

   Confirm that the session names above appear in the picker, then press
   `Ctrl-C` to exit the verification TUI.
3. Refresh the destination VS Code Codex conversation list. Open the Command
   Palette, run `Developer: Reload Window`, and reopen the Codex sidebar.

Step 3 is needed when the restore ran while VS Code/Codex was already open: the
active panel can retain the pre-restore thread list even after the rollout and
local state database contain the restored threads. Running `codex resume` in a
separate terminal does not itself refresh that panel cache.

### Remote/headless restore panel restart

Use this fallback only during a future restore when the user explicitly asks an
agent to restart the panel and cannot run `Developer: Reload Window`:

1. Verify the restored sessions with `codex resume --all` and exit the TUI.
2. Locate the exact OpenAI Codex `app-server` process under the active
   `openai.chatgpt-*` VS Code extension. Resolve its immediate parent and verify
   that it is the remote VS Code extension host under `.vscode-server`; never
   use a broad `pkill` pattern.
3. Finish and persist the recovery turn before restarting anything. Schedule a
   targeted `SIGTERM` to that verified extension-host PID after a 10-15 second
   delay so the response reaches the user.
4. Never terminate the VS Code server, remote agent, unrelated extension hosts,
   or every `node`/`codex` process. After reconnection, reopen the Codex sidebar
   and confirm that all saved names are listed.

The official Codex CLI command reference for resuming saved chats is at
<https://developers.openai.com/codex/cli/reference>.
