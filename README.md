# Personal Codex setup

`setup` 브랜치는 개인 설정을 다른 환경에서 복원하고 업데이트하기 위한 저장소입니다.

- `.codex/AGENTS.md`: 개인 작업 지침
- `.agents/skills/`: 개인 스킬과 지원 파일
- `README.md`: 환경별 설치 및 설정 안내

Codex 기본 스킬, 플러그인 캐시, 메모리, 인증 정보 및 전체 `config.toml`은 관리하지 않습니다.

## 복원 및 업데이트

1. `setup` 브랜치를 체크아웃하고 `git pull --ff-only`로 갱신합니다.
2. 대상 환경의 기존 개인 지침과 스킬을 백업합니다.
3. `.codex/AGENTS.md`를 대상 Codex 홈의 `AGENTS.md`에 복원합니다.
4. `.agents/skills/`의 개인 스킬을 대상 Codex가 인식하는 개인 스킬 위치에 복원합니다. 원본 Windows 환경에서는 `C:\Users\user\.codex\skills`를 사용합니다. 대상 환경의 기본 스킬과 플러그인은 보존합니다.
5. 아래 환경 설정을 확인합니다. 전체 로컬 설정이나 인증 파일을 저장소에 복사하지 않습니다.

업데이트할 때는 의도한 개인 지침, 개인 스킬, README만 명시적으로 스테이징하고 변경 내용을 확인한 뒤 커밋합니다.

## 실험적 컨텍스트 관리 켜기

이 항목은 사용자가 이 저장소를 이용해 환경 설정을 요청했을 때 적용하는 설치 절차입니다. 저장소를 복제하거나 README를 읽는 것만으로 기능이 켜지지는 않습니다.

1. Codex가 실제로 실행되는 호스트와 사용자 계정을 확인합니다. VS Code에서는 Codex 설정의 **Open config.toml**로 실제 설정 파일을 여는 것이 좋습니다.
2. 해당 환경의 사용자 `config.toml`을 백업합니다. 기본 위치는 `~/.codex/config.toml`이며 `CODEX_HOME`이 지정되어 있다면 해당 홈의 설정을 확인합니다.
3. 지원되는 환경에서 이 기능이 꺼져 있으면 아래 값을 활성화합니다. 같은 키나 테이블이 이미 있으면 기존 값을 수정하고 중복으로 추가하지 않습니다. 다른 설정은 보존합니다.

```toml
[features.context_management]
experimental_mode = true
```

4. 컨텍스트 크기(`model_context_window`)와 자동 압축 임계값(`model_auto_compact_token_limit`)은 별도 요청이 없으면 기존 값 또는 모델 기본값을 유지합니다.
5. 앱 또는 VS Code 창을 다시 로드하고 새 작업에서 사용합니다. 이미 실행 중인 작업이 즉시 새 설정을 적용했다고 가정하지 않습니다.
6. 같은 호스트, 사용자, Codex 홈을 사용하는 CLI가 있다면 다음 명령으로 지원 여부와 설정 인식을 확인합니다.

```sh
codex --version
codex features list
```

`context_management`가 `true`인지 확인합니다. 항목 자체가 없다면 Codex CLI/확장을 업데이트하고 현재 공식 문서를 확인합니다. CLI의 `true`는 설정 인식 확인이며, 다른 버전의 VS Code 확장이나 실제 장기 대화의 동작까지 검증한 것은 아닙니다.

현재 공식 문서는 이 기능을 실험적 기능으로 설명하며 ChatGPT Plus, Pro 또는 Pro Lite 로그인을 요구합니다. API 키 사용 환경에도 동일하게 제공된다고 가정하지 않습니다. 조직에서 관리하는 제한이 있다면 그 정책을 따릅니다.

### 원격 VS Code / SSH / WSL / 컨테이너

로컬 PC의 설정이 원격 환경으로 자동 동기화된다고 가정하지 않습니다. 확장이 로컬에서 실행되는지, 원격 호스트에서 실행되는지 확인하고 실제 Codex 실행 환경의 설정에 위 값을 적용합니다. 다른 계정이나 별도의 `CODEX_HOME`을 쓰는 환경도 각각 확인해야 합니다.

환경 설치 시 Codex에 다음처럼 요청할 수 있습니다.

> 이 저장소의 setup 브랜치 README에 따라 개인 설정을 복원하고, 현재 실행 환경에서 지원되는 컨텍스트 관리 기능이 꺼져 있다면 켜줘. 기존 설정과 기본 스킬은 보존하고, 컨텍스트 크기는 변경하지 마.

이 내용은 환경 설치 절차이므로 `AGENTS.md`에 매 작업마다 수행하는 지침으로 넣지 않습니다.

## 확인 기록 및 공식 문서

- 2026-09-06: 원본 Windows 환경의 Codex CLI `0.153.4`에서 영구 설정 후 `context_management`가 `true`로 인식됨을 확인했습니다. 컨텍스트 크기는 변경하지 않았습니다. 다른 원격 환경은 별도로 적용 및 확인해야 합니다.
- [공식 설정 안내](https://learn.chatgpt.com/docs/config-file/config-basic)
- [공식 설정 레퍼런스](https://learn.chatgpt.com/docs/config-file/config-reference)
