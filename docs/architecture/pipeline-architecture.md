# Pipeline Architecture

## 4-Layer Model

```
┌─────────────────────────────────────────────────────────────────┐
│                        taco-claude Pipeline                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Layer 1: FRAMING              Layer 2: DESIGN                  │
│  ┌──────────┐ ┌──────────┐    ┌──────────┐ ┌──────────────┐   │
│  │brainstorm│→│ specify  │─G1→│   plan   │→│ review-plan  │   │
│  └──────────┘ └──────────┘    └──────────┘ └──────────────┘   │
│   idea.md      spec.md         plan.md      plan-review.md     │
│                                                     │          │
│                                                    G2          │
│                                                     │          │
│  Layer 3: DELIVERY             Layer 4: EVOLUTION   ▼          │
│  ┌──────────┐ ┌──────────────┐ ┌──────────┐                   │
│  │implement │→│ review-code  │→│  learn   │                    │
│  └──────────┘ └──────────────┘ └──────────┘                   │
│   code+commit  code-review.md   learnings/                     │
│                       │                                        │
│                      G3                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Layer 상세

### Layer 1: Framing (탐색 → 정의)

```
 사용자 아이디어
       │
       ▼
 ┌──────────────┐    Socratic Q&A     ┌──────────────┐
 │  /brainstorm │ ──────────────────→ │   idea.md    │
 │              │    explorer agent    │  Problem     │
 │  Claude      │    critic agent     │  Solution    │
 │              │    researcher agent  │  Risks       │
 └──────────────┘                     │  References  │
                                      └──────┬───────┘
                                             │
                                             ▼
 ┌──────────────┐    Interview-driven ┌──────────────┐
 │   /specify   │ ──────────────────→ │   spec.md    │
 │              │    explorer agent    │  Overview    │
 │  Claude      │                     │  Scenarios   │
 │              │                     │  Requirements│
 └──────────────┘                     │  Technical   │
                                      │  Testing     │
                                      └──────────────┘
```

### Layer 2: Design (설계 → 검증)

```
 spec.md
    │
    ▼
 ┌──────────────┐                    ┌──────────────┐
 │    /plan     │ ────────────────→  │   plan.md    │
 │              │    explorer agent   │  Architecture│
 │  Claude      │    critic agent     │  Tasks       │
 │              │                     │  Risks       │
 └──────────────┘                     └──────┬───────┘
                                             │
                    ┌────────────────────────┤
                    │           │            │
                    ▼           ▼            ▼
              ┌──────────┐┌──────────┐┌──────────┐
              │  Claude  ││  Codex   ││  Gemini  │
              │  논리적   ││  구현     ││  대안     │
              │  일관성   ││  실현성   ││  엣지     │
              └────┬─────┘└────┬─────┘└────┬─────┘
                   │           │           │
                   └───────────┼───────────┘
                               ▼
                    ┌──────────────────┐
                    │  /review-plan    │
                    │  합성 → SHIP?    │
                    │  plan-review.md  │
                    └──────────────────┘
```

### Layer 3: Delivery (구현 → 코드 리뷰)

```
 plan.md + approved
    │
    ▼
 ┌──────────────────────────────────┐
 │          /implement              │
 │  ┌────────────────────────────┐  │
 │  │     Orchestrator (Claude)  │  │
 │  │  plan.md → Task 분해       │  │
 │  └──────┬──────┬──────┬───────┘  │
 │         │      │      │          │
 │         ▼      ▼      ▼          │
 │  ┌──────┐┌──────┐┌──────┐       │
 │  │Worker││Worker││Worker│       │
 │  │Task 1││Task 2││Task 3│       │
 │  └──┬───┘└──┬───┘└──┬───┘       │
 │     │       │       │            │
 │     └───────┼───────┘            │
 │             ▼                    │
 │      git commit (worktree)       │
 │  ┌─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐   │
 │  │ Docker sandbox (optional) │   │
 │  │ --network none            │   │
 │  │ --read-only               │   │
 │  │ --cap-drop ALL            │   │
 │  └─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘   │
 └──────────────────────────────────┘
          │
          ▼
 ┌──────────────────┐
 │  /review-code    │    3-model review
 │  Claude+Codex    │ →  code-review.md
 │  +Gemini         │    SHIP / NEEDS_FIXES
 └──────────────────┘
```

### Layer 4: Evolution (회고 → 학습)

```
 code-review SHIP
    │
    ▼
 ┌──────────────────────────────────────────┐
 │              /learn                       │
 │                                           │
 │  1. 전체 히스토리 분석                      │
 │     idea → spec → plan → reviews → code   │
 │                                           │
 │  2. 회고 작성                              │
 │     What worked / What failed / Surprises │
 │                                           │
 │  3. 규칙 업데이트 제안                      │
 │     → CLAUDE.md                           │
 │     → templates/                          │
 │     → domains/*/KNOWLEDGE.md              │
 │                                           │
 │  4. 학습 기록 저장                          │
 │     → docs/learnings/{date}-{name}.md     │
 │     → docs/learnings/index.md 업데이트     │
 └──────────────────────────────────────────┘
```

## Gate System

```
             G1                    G2                    G3
             │                     │                     │
 ┌─────┐ ┌──┴───┐ ┌────┐ ┌───────┴──┐ ┌─────────┐ ┌───┴────┐ ┌─────┐
 │brain│→│spec  │→│plan│→│review    │→│implement│→│review  │→│learn│
 │storm│ │ify   │ │    │ │-plan     │ │         │ │-code   │ │     │
 └─────┘ └──────┘ └────┘ └──────────┘ └─────────┘ └────────┘ └─────┘

 G1: spec.md에 5개 필수 섹션 존재
     Overview, User Scenarios, Core Requirements,
     Technical Details, Testing Plan

 G2: plan-review.md에 SHIP 판정
     3-model 합의 또는 다수결

 G3: code-review.md에 SHIP 판정
     verify-report.md PASS
```

## Model Distribution

```
 ┌─────────────────────────────────────────────────┐
 │                Model Assignment                  │
 ├─────────────┬───────────────────────────────────┤
 │  Claude     │  brainstorm, specify, plan, learn │
 │  (default)  │  사고, 문서화, 분석                 │
 ├─────────────┼───────────────────────────────────┤
 │  Codex CLI  │  implement (via worker)           │
 │  (optional) │  코드 생성                         │
 ├─────────────┼───────────────────────────────────┤
 │  3-Model    │  review-plan, review-code         │
 │  Claude +   │  다각도 리뷰                       │
 │  Codex +    │  합성 → SHIP/NEEDS_FIXES          │
 │  Gemini     │                                   │
 └─────────────┴───────────────────────────────────┘

 Graceful Degradation:
   Codex 없음  → Claude가 코드 생성 담당
   Gemini 없음 → 2-model 또는 Claude-only 리뷰
   둘 다 없음  → Claude 단독 (모든 기능 동작)
```

## Hook System

```
 User Prompt
    │
    ├─── UserPromptSubmit ──→ state-manager.sh
    │    /brainstorm 감지?       상태 전이 + 게이트 체크
    │    /specify 감지?          이벤트 로깅
    │
    ├─── PreToolUse[Edit|Write] ──→ guard.sh
    │    파일 경로 검사              단계별 접근 제어
    │    민감 파일 차단              allow / deny
    │
    └─── PostToolUse[Task|Skill] ──→ validate.sh
         validate_prompt 추출           + next-step.sh
         완료 검증 안내                   다음 단계 안내
```

## File Flow

```
 Runtime (.dev/ — git-ignored)        Durable (git-tracked)
 ─────────────────────────────        ─────────────────────
 .dev/
 ├── state.json ← 파이프라인 상태
 ├── enabled_packs ← 활성 도메인 팩
 ├── events.jsonl ← 감사 로그
 └── specs/{feature}/
     ├── idea.md     ← brainstorm      docs/learnings/
     ├── spec.md     ← specify         ├── index.md
     ├── plan.md     ← plan            └── {date}-{name}.md
     ├── tasks.md    ← implement
     └── reviews/                       domains/{pack}/
         ├── plan-review.md             ├── KNOWLEDGE.md
         ├── code-review.md             └── LEARNINGS.md
         └── verify-report.md
```
