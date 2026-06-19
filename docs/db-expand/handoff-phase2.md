# 핸드오프 — 번들 DB 확장: Phase 2(일관성 점검)부터

> **사용법.** 새 세션에서 *"이 파일(`docs/db-expand/handoff-phase2.md`) 읽고 이어서 진행해줘"* 라고 하면 된다.
> 진행 상태의 정본은 디스크다 — 충돌 시 이 핸드오프가 아니라 [`ROADMAP.md`](../../ROADMAP.md) "Now"와 [`spec.md`](spec.md)를 신뢰할 것.

## 지금 어디까지 (2026-06-19)

- 브랜치: `feat/bundle-db-pre-launch-expand`
- **round-001 (10 keyword POC) 완료**: validator 10/10 통과, 커밋 `c0ee991`. **아직 `terms.json` 머지 안 됨.**
- alias 룰 **v2.1.1**까지 개정 (닫힌 목록 → "이름이냐 설명이냐" 원칙 지배, (5) 다른 언어 정식 동의어 허용).
- 사람 손 시간 ≈60분 → **Phase 7 자동화 무조건 진행 결정**.
- Anthropic API 크레딧 확보 (~$195) → API 사용 가능.

## 정본 문서 (이걸 읽고 신뢰)

| 무엇 | 경로 |
|---|---|
| 마스터 상태·체크리스트 | [`ROADMAP.md`](../../ROADMAP.md) "Now" |
| 단계 상세·drift gate 정의 | [`spec.md`](spec.md) (Phase 2 섹션) |
| round-001 결과 | [`rounds/round-001.json`](rounds/round-001.json) · [`rounds/round-001.md`](rounds/round-001.md) |
| 수동 라운드 흐름 | [`runbook-manual-round.md`](runbook-manual-round.md) |
| 프롬프트 (v2.1.1) | `Scripts/db-expand/prompts/{v2-batch,critic-v1}.md` |
| 도구 | `Scripts/db-expand/{validator.py, merge.py}` |

## 다음 작업: Phase 2 — 일관성 점검

목적: round-001을 머지하기 전 품질·일관성 안전장치. **통과 못 하면 Phase 1로 회귀.** 두 점검(A·B) 모두 spec Phase 2의 임계값을 정본으로 따를 것.

### (A) 기존 terms.json 베이스라인 비교 — [코드, API 불필요] → 먼저 시작
- 입력: `round-001.json` + 기존 `terms.json`에서 **카테고리별 균등 sample** (예: 카테고리당 5개).
- **drift gate** (spec 참조): 신규 batch validator 통과율 100% / alias 개수 중앙값 동일 / 톤 빈도(부사·감탄사·과장 형용사) 신규가 sample 대비 명백히 증가하지 않음.
  - ⚠️ legacy sample은 length 룰 비순응(grandfather)이라 **길이 비교 대상 아님** — 길이 평균·분포는 informational only(기록만).
- 산출물: `docs/db-expand/rounds/round-001-consistency-A.md`

### (B) chat↔API drift 검증 — [코드, API 필요 — 크레딧 OK]
- ⚠️ **선행 작업: `Scripts/db-expand/api_sample.py`가 아직 없음 → 작성 필요.**
  - `Scripts/generate_db.py`의 `call_claude` 재사용. `prompts/v2-batch.md` system prompt + round-001의 keyword 5~10개를 API로 재실행.
  - 모델 id는 `generate_db.py` / `ClaudeAPIService.swift`의 production 값과 동일하게 맞출 것. **Anthropic API를 건드리므로 작업 전 `claude-api` 스킬로 모델 id·파라미터 확인 권장.**
- **drift threshold** (spec): validator 통과율 동일, 같은 keyword pair의 길이 편차 ±15% 이내.
- 산출물: `docs/db-expand/rounds/round-001-consistency-B.md`

## Phase 2 통과 후 (이번 세션 범위 밖일 수 있음)

- **Phase 3**: `merge.py`로 `terms.next.json` → iOS smoke test(사람 승인 게이트) → `terms.json` swap + 커밋. (⚠️ 비가역 번들 변경)
- **Phase 4**: 목표 N 결정 + Phase 5 `critic-v2` 발주(정량 룰 제거 — round-001에서 critic 고유 검출 0으로 근거 확보).
- **Phase 7 자동화**: 진행 결정됨. Phase 5 이후 loop 설계 고려.

## 규칙 (CLAUDE.md / 사용자)

- 커밋: Conventional Commits, **scope 없이** (`feat:`/`docs:`/`chore:`), **Co-Authored-By 트레일러 금지**.
- 진행 상태 정본은 디스크(ROADMAP·round 문서). **메모리에 status 쓰지 말 것.**
- 전문가 에이전트엔 해답 박지 말고 문제·제약만 주고 진단·구현하게 할 것.

## 가장 먼저 할 것

`api_sample.py`가 없으니 **Phase 2A(코드만)부터 시작**하고, 병행해서 `api_sample.py`를 작성한 뒤 Phase 2B로. 시작 전 사용자에게 "2A 먼저 vs 2A+2B 한 번에" 확인하면 깔끔.
