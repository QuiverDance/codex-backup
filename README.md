# GH200 Codex conversation backup

This orphan branch contains a point-in-time backup of indexed active local
Codex conversations found under `sessions/` on the GH200 server. Deleted
conversations under `archived_sessions/` and unindexed internal helper sessions
are excluded. Credential-shaped values are redacted from the exported snapshot
without modifying the local source files. The current snapshot's session count
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

## 필수 백업·업로드 원칙 (에이전트 포함)

사용자가 현재 로컬 대화를 원격에 반영해 달라고 요청하면 **로컬 → 원격
`gh200` 백업**을 수행합니다. 원격 기록을 로컬에 복원하는 요청으로 해석하지
않습니다.

1. 원격 `gh200`을 fetch하고 기존 작업 트리 변경을 확인합니다. 원격과 로컬이
   갈라졌다면 변경을 보존해 정리하고, 강제 push로 원격 기록을 덮어쓰지 않습니다.
2. 위 exporter로 로컬의 **인덱스에 등록된 활성 세션** 스냅샷을 만듭니다.
   `archived_sessions/`와 인덱스에 없는 내부 보조 세션은 제외합니다.
   아카이브되거나 삭제되어 활성 집합에서 빠진 세션은 원격 최신 스냅샷의
   `session_parts/`, manifest, index에서도 제거합니다. 과거 Git 커밋의 기록까지
   지우거나 이력 전체를 재작성하는 작업은 아닙니다.
3. 원격 기준 커밋과 파일 해시/Git diff를 비교해 **새 파일, 변경 파일, 삭제만**
   반영합니다. exporter가 로컬 분할 파일을 재생성하더라도 내용이 같은 파일은
   재업로드하지 않습니다. 변경이 없으면 불필요한 업로드를 하지 않습니다.
4. 세션 백업 전송은 **인증된 Git의 commit + push**로 묶어서 수행합니다.
   Git이 변경 객체를 pack/delta로 전송하게 하고, 분할 파일마다 GitHub API를
   수백 번 순차 호출하는 방식으로 대체하지 않습니다.
5. **세션 원문이나 Base64 데이터를 에이전트 도구 출력 또는 도구 인자로
   통과시키지 않습니다.** `cat`, `base64 -w0` 등으로 세션/분할 파일 내용을
   출력하거나, 그 결과를 `github_create_blob` 등의 인자로 전달하지 않습니다.
   중간 결과를 화면에 표시하지 않더라도 도구 기록에 저장될 수 있습니다.
   파일 내용은 로컬 파일과 Git 프로세스 사이에서만 처리하고, 에이전트에는
   개수·크기·해시·성공 여부 등 작은 요약만 반환합니다.
6. Git 인증이 없다면 기존에 승인된 Git 인증 수단을 확인합니다. 연결된 GitHub
   앱이 있다는 사실만으로 셸의 Git 인증도 가능하다고 가정하지 않습니다.
   승인된 인증 수단으로 해결할 수 없다면 **로컬 스냅샷과 커밋을 준비한 상태에서
   업로드 미완료 및 필요한 Git 인증을 명확히 알립니다.** 토큰을 출력하거나
   대화로 요청하지 않고, 대용량 내용을 GitHub 앱 도구에 실어 보내는 방식으로
   우회하지 않습니다.
7. push 후 원격 브랜치 커밋과 준비한 스냅샷의 tree/hash 일치를 확인합니다.
   완료 보고에는 세션 수, 스냅샷 기준 시각, 원격 커밋을 적습니다. 백업 중 계속
   쓰이는 현재 대화는 스냅샷 경계까지만 포함합니다. 진행 보고를 포함시키려고
   반복 백업하지 않습니다.

**재발 방지 배경:** 2026-09-09에 분할 파일을 Base64 도구 출력으로 읽고
GitHub 앱으로 개별 업로드하면서 전송 내용 자체가 현재 대화 기록에 저장됐습니다.
그 결과 백업 대화 하나가 약 0.4 MB에서 95.5 MB로 증가했고, 다음 백업에서
486개 변경 파일을 순차 업로드하는 지연을 만들었습니다. 이 방식은 다음 백업의
크기까지 키우므로 사용하지 않습니다. 자격 증명 패턴 제거는 기존 exporter에서
계속 수행하며, 속도를 위해 검증이나 비밀정보 제거를 생략하지 않습니다.

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
