# taco-harness

개인 개발 워크플로우를 구조화하는 Claude Code 플러그인.

아이디어부터 학습까지 7단계 파이프라인으로 개발 과정을 안내하고,
단계별 보안 가드와 3-model 리뷰로 품질을 보장한다.

## 왜 만들었나

- 코드부터 짜고 나중에 후회하는 패턴을 깨고 싶었다
- "생각 → 설계 → 구현 → 검증 → 학습" 흐름을 강제하고 싶었다
- Claude만으로는 놓치는 관점을 Codex, Gemini로 보완하고 싶었다

## 파이프라인

```
/brainstorm → /specify → /plan → /review-plan → /implement → /review-code → /learn
   탐색         정의       설계      계획 리뷰       구현         코드 리뷰      회고
```

| 단계 | 명령어 | 하는 일 | 결과물 |
|------|--------|---------|--------|
| 1 | `/brainstorm <name>` | 소크라틱 Q&A로 아이디어 탐색 | idea.md |
| 2 | `/specify <name>` | 인터뷰 기반 스펙 작성 | spec.md |
| 3 | `/plan <name>` | 태스크 분해 + 기술 계획 | plan.md |
| 4 | `/review-plan <name>` | 3-model 계획 리뷰 + Draft PR 생성 | plan-review.md |
| 5 | `/implement <name>` | Orchestrator-Worker 패턴으로 구현 | 코드 커밋 |
| 6 | `/review-code <name>` | 3-model 코드 리뷰 + PR Ready | code-review.md |
| 7 | `/learn <name>` | 회고 분석 + 학습 기록 | learnings/*.md |

각 단계가 끝나면 다음 단계를 자동으로 안내한다.

## 설치

### 요구사항

- Claude Code
- `jq` (JSON 처리)

### 선택 사항

- `codex` CLI — Codex 모델 사용 (없으면 Claude만으로 동작)
- `gemini` CLI — Gemini 모델 사용 (없으면 스킵)
- `gh` CLI — GitHub PR 자동 생성
- `docker` — 구현 단계 격리 실행

### 플러그인 설치

마켓플레이스에서 설치:

```
/plugin marketplace add mildsalmon/taco-harness
/plugin install taco@mildsalmon
```

설치 후 Claude Code를 재시작하면 플러그인이 로드된다.

### taco CLI 설치 (선택)

터미널에서 바로 `taco` 명령어를 쓸 수 있다:

```bash
~/source_code/harness/taco-harness/scripts/install-taco.sh
```

기본으로 `~/.local/bin/taco`에 심볼릭 링크를 생성한다.
다른 경로를 원하면 인자로 전달:

```bash
~/source_code/harness/taco-harness/scripts/install-taco.sh /usr/local/bin
```

`~/.local/bin`이 PATH에 없으면 셸 설정에 추가:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

## 빠른 시작

### 단계별 실행 (Claude Code에서)

```
/brainstorm user-auth          # 1. 아이디어 탐색
/specify user-auth             # 2. 스펙 작성
/plan user-auth                # 3. 기술 계획
/review-plan user-auth         # 4. 계획 리뷰 (3-model)
/implement user-auth           # 5. 구현
/review-code user-auth         # 6. 코드 리뷰 (3-model)
/learn user-auth               # 7. 회고 + 학습
```

### 오토파일럿 (한방에 실행)

```
/run user-auth                 # 전체 파이프라인 실행 (게이트마다 체크포인트)
/run user-auth --auto          # 완전 자동 (게이트 실패 시만 정지)
/run user-auth --from plan     # 특정 단계부터 재개
```

### taco CLI (터미널에서)

```bash
taco                           # 인터랙티브 모드 (feature 선택 메뉴)
taco init                      # 현재 프로젝트에 .dev/ 초기화
taco new user-auth             # feature 생성
taco list                      # feature 목록
taco status                    # 파이프라인 상태
taco gate G1 user-auth         # gate 검증
taco events                    # 최근 이벤트 로그
taco run user-auth             # 오토파일럿 안내
taco pack list                 # 도메인 팩 목록
taco model check               # 외부 모델 CLI 가용성 확인
```

순서를 건너뛰면 경고가 뜬다:
```
/implement user-auth
→ "WARNING: G2 not passed — plan not approved. Run /review-plan first."
```

## Gate (관문)

이전 단계가 완료되지 않으면 경고를 표시한다.

| Gate | 시점 | 검증 내용 |
|------|------|----------|
| G1 | /plan 진입 | spec.md에 5개 필수 섹션이 있는가 |
| G2 | /implement 진입 | plan-review에서 SHIP 판정을 받았는가 |
| G3 | /learn 진입 | code-review에서 SHIP 판정을 받았는가 |

## 3-Model 리뷰

review-plan과 review-code에서 세 모델의 관점을 합성한다:

- **Claude** — 논리적 일관성, 완전성, 보안
- **Codex** — 구현 실현성, 코드 품질
- **Gemini** — 대안 접근, 엣지케이스

Codex나 Gemini가 없으면 Claude만으로 진행한다 (graceful degradation).

## 보안

### 단계별 파일 접근 제어

guard.sh가 단계에 따라 쓰기를 제한한다:

| 단계 | 쓰기 허용 범위 |
|------|--------------|
| brainstorm, specify, plan | `.dev/` 내부만 |
| review-plan, review-code | 읽기만 가능 |
| implement | 프로젝트 디렉토리 (worktree) |
| learn | `docs/learnings/`, `CLAUDE.md`, `templates/` |

`.env`, `.ssh`, `credentials` 등 민감 파일은 어떤 단계에서든 차단된다.

### Docker 샌드박스

implement 단계에서 Docker 격리 실행을 지원한다:
- 네트워크 차단 (`network_mode: none`)
- 읽기 전용 루트 파일시스템
- 비루트 사용자 (uid 10001)
- 모든 커널 권한 제거

## CLI

### taco 명령어 (권장)

프로젝트 디렉토리에서 바로 실행. 프로젝트 루트를 자동 감지한다 (`.dev/` 또는 `.git/` 탐색).
인자 없이 실행하면 인터랙티브 모드로 진입한다:

```bash
taco                           # 인터랙티브 모드 (feature 선택/생성)
taco init                      # 현재 프로젝트에 .dev/ 초기화
taco new <이름>                 # feature 생성
taco list                      # feature 목록
taco status                    # 파이프라인 상태
taco gate <G1|G2|G3> <이름>    # gate 검증
taco events [개수]              # 이벤트 로그 (기본 20개)
taco run <이름>                 # 오토파일럿 안내
taco pack list                 # 도메인 팩 목록
taco pack enable <이름>         # 팩 활성화
taco pack disable <이름>        # 팩 비활성화
taco model check               # 외부 모델 CLI 가용성 확인
```

### taco.sh (저수준)

프로젝트 경로를 명시적으로 전달:

```bash
./scripts/taco.sh init <프로젝트경로>                    # 초기화
./scripts/taco.sh feature new <프로젝트경로> <이름>       # feature 생성
./scripts/taco.sh feature list <프로젝트경로>             # feature 목록
./scripts/taco.sh gate check G1 <프로젝트경로> <이름>     # gate 검증
./scripts/taco.sh state show <프로젝트경로>               # 파이프라인 상태
./scripts/taco.sh events <프로젝트경로> [개수]             # 이벤트 로그
./scripts/taco.sh pack list <프로젝트경로>                # 팩 목록
./scripts/taco.sh model check                            # 모델 CLI 확인
```

## 알림 설정

```
/setup-notify
```

Telegram 또는 Discord를 선택하고 토큰/웹훅을 입력하면,
리뷰 완료나 구현 완료 시 알림을 받을 수 있다.

## 도메인 팩

특정 도메인(회계, 의료 등)의 전문 지식을 파이프라인에 주입할 수 있다.
`templates/domains/`의 템플릿을 참고해서 `domains/` 아래에 팩을 만든다:

```
domains/my-domain/
├── MANIFEST.md          # 팩 정보 + 주입 포인트
├── BOUNDARY.md          # 범위 정의
├── GLOSSARY.md          # 용어 사전
├── KNOWLEDGE.md         # 검증된 규칙
├── LEARNINGS.md         # 검증 중인 학습
├── RISK_CHECKLIST.md    # 리스크 체크리스트
├── SPEC_ADDON.md        # 추가 요구사항
└── VERIFY_SCENARIOS.md  # 검증 시나리오
```

팩 관리:
```bash
taco pack list               # 팩 목록
taco pack enable my-domain   # 팩 활성화
taco pack disable my-domain  # 팩 비활성화
```

## 프로젝트 구조

```
taco-harness/
├── .claude-plugin/plugin.json   # 플러그인 등록
├── hooks/hooks.json             # Hook 정의
├── scripts/                     # 14개 bash 스크립트 + taco CLI
│   ├── lib/common.sh            # 공유 유틸리티 라이브러리
│   └── ...
├── agents/                      # 5개 에이전트 (explorer, critic, reviewer, worker, researcher)
├── skills/                      # 9개 스킬 (7 파이프라인 + run 오토파일럿 + setup-notify)
├── sandbox/                     # Docker 격리 실행 환경
├── templates/                   # 스펙, 계획, 검증, 태스크, 도메인 템플릿
├── docs/
│   ├── security/                # 보안 정책 문서 8개
│   └── architecture/            # 아키텍처 시각화
├── tests/smoke.sh               # 자동 스모크 테스트
├── CLAUDE.md                    # Claude Code용 프로젝트 규칙
└── README.md                    # 이 파일
```

### 런타임에 생성되는 파일 (.dev/는 git-ignored)

```
{프로젝트}/
├── .dev/
│   ├── state.json               # 파이프라인 상태
│   ├── events.jsonl             # 이벤트 감사 로그
│   └── specs/{feature}/
│       ├── idea.md              # brainstorm 결과
│       ├── spec.md              # specify 결과
│       ├── plan.md              # plan 결과
│       ├── tasks.md             # 태스크 추적
│       └── reviews/             # 리뷰 결과
└── docs/learnings/              # git-tracked 학습 기록
```

## 테스트

```bash
./tests/smoke.sh
```

15개 테스트: 스크립트 실행 가능 여부, JSON 유효성, init/feature/gate/state-manager/guard/agent/skill 검증.

## 설계 원칙

- **bash/sh 전용** — 외부 의존성 없음 (jq만 예외)
- **개인 사용 최적화** — 팀 협업이 아닌 1인 개발 흐름에 집중
- **점진적 도입** — 모든 단계를 다 쓸 필요 없음, 필요한 것만 사용
- **graceful degradation** — Codex/Gemini/Docker 없어도 동작
- **파일 기반 상태** — DB 없이 JSON/Markdown 파일로 모든 상태 관리
