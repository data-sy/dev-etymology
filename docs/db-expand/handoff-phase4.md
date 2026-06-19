# 핸드오프 — 번들 DB 확장: Phase 4(회고·목표 N 결정)부터

> **사용법.** 새 세션에서 *"이 파일(`docs/db-expand/handoff-phase4.md`) 읽고 이어서 진행해줘"* 라고 하면 된다.
> 진행 상태의 정본은 디스크다 — 충돌 시 이 핸드오프가 아니라 [`ROADMAP.md`](../../ROADMAP.md) "Now"와 [`spec.md`](spec.md), [`rounds/round-001.md`](rounds/round-001.md)를 신뢰할 것.

## 지금 어디까지 (2026-06-19)

- 브랜치: `feat/bundle-db-pre-launch-expand` (미PR)
- **round-001 종결.** 번들 DB **500 → 510** 머지·커밋 완료 (`e11cf15`). 기존 500 무손실, 신규 10개만 추가, `keyword.lower()` 알파벳 정렬.
- **Phase 2A** PASS (3 게이트 + robust 전수/스윕 교차검증). **Phase 2B** 임계값 FAIL이나 **drift 원인 식별**(루프 후 cycle-2 최종본 vs API 단발 비대칭 + 단발 길이 초과 — prompt mismatch 아님) → 사용자 결정 **(a)** 로 머지 진행.
- **Phase 3 iOS smoke PASS** (iPhone 17 시뮬레이터): 빌드·terms.json(510) 번들·런치 크래시 없음·재시작 로딩 + 신규 keyword/alias(한+영)/카테고리 검색 결정론 확인.
- 커밋: `ca9674a`(test: 2B 도구·보고서) / `e11cf15`(feat: 510 머지) / `4290c93`(docs: 상태 현재화).

## 정본 문서 (이걸 읽고 신뢰)

| 무엇 | 경로 |
|---|---|
| 마스터 상태·체크리스트 | [`ROADMAP.md`](../../ROADMAP.md) "Now" (현재 다음=Phase 4) |
| 단계 상세·Phase 4 질문 | [`spec.md`](spec.md) (Phase 4 섹션) |
| round-001 회고 데이터 | [`rounds/round-001.md`](rounds/round-001.md) — critic 고유검출·scope leak·분포·길이오차 등 **이미 대부분 기록됨** |
| 2A 결과 | [`rounds/round-001-consistency-A.md`](rounds/round-001-consistency-A.md) |
| 2B 결과 (Phase 7 입력) | [`rounds/round-001-consistency-B.md`](rounds/round-001-consistency-B.md) |
| 도구 | `Scripts/db-expand/{validator.py, merge.py, consistency_a.py, consistency_a_robust.py, api_sample.py}` |
| 프롬프트 | `Scripts/db-expand/prompts/{v2-batch.md, critic-v1.md}` |

## 다음 작업: Phase 4 — 회고 [수동·사람 결정 지점]

목적: round-001 회고를 마감하고 **목표 N(출시 전 도달 크기)을 결정**, Phase 5(critic-v2) 발주.

### 회고 질문 (spec Phase 4) — 대부분 round-001.md에 답 있음, 검토만
- **분리 효용**: critic이 validator 외 유니크하게 잡은 것 → round-001 기준 **0건** (정량 룰 overlap만). 근거 확보됨.
- **길이 카운팅 오차**: 이번 라운드 critic 길이 판정과 코드 카운트 불일치 없음 (표본 작음, Phase 6 누적 관찰).
- **통신 프로토콜**: critic feedback → 재생성 fix 유발 확인 (cycle 1→2).
- **Scope leak**: 0건 (재생성이 대상 외 entry 안 건드림).
- **분포 점검**: 신규 10개 카테고리 균등(각 2, 기타 0) — 기타 137 편중 회피 의도 달성.

### 남은 미결 (Phase 4 Done 조건)
1. **목표 N 결정 [사람]** — round당 throughput(생성 2 cycle, 사람 손 시간 ≈60분/POC) + 품질 기준으로 출시 전 도달 가능 N 산정안을 AI가 제시 → 사람 확정.
2. **spec Done 신호 갱신** — 확정된 목표 N을 [`spec.md`](spec.md) "Done 신호"에 반영.
3. **critic-v2 작성 (Phase 5)** — round-001 critic 고유검출 0 근거로 정량 룰 전부 제거, nuanced 룰만(`ALIAS_STRICT` 의미판단·`ETYMOLOGY_FACT`·`NAMING_COHERENCE`). `prompts/critic-v2.md`.
4. **scope_diff.py 작성 (Phase 5)** — `Scripts/db-expand/scope_diff.py` (before/after/failed_keywords → scope_leak 검출, aliases 정렬 비교).
5. **다음 라운드 변경 후보 3개+** — round-001.md에 기록됨, Phase 6 발주 시 반영.

### 2B에서 가져온 입력 (Phase 7 자동화 설계용 — 잊지 말 것)
- **API 단발은 길이 룰 비순응**(validator 1/10)이 정량 확인됨. chat round-001 품질은 validator→재생성 루프에서 나온 것. → Phase 7 loop는 `Generator(API) → validator → 재생성`이 필수. (spec Phase 7에 이미 포함, 근거 데이터 = `round-001-consistency-B.md`.)
- `api_sample.py`로 공정 재검(API 출력을 루프 태워 수렴 확인) 가능. 실제 API 키는 `Scripts/db-expand/.env.local`에 보존됨(gitignore). 사용 전 `claude-api` 스킬로 모델 id 재확인 권장(현재 production = `claude-sonnet-4-6`).

## Phase 4 통과 후

- **Phase 5**: critic-v2 + scope_diff 흐름 확립 (`Generator → validator → critic(v2) → 재생성 → scope_diff → 머지`).
- **Phase 6**: 30~50 keyword 확장 batch (Phase 0-1 keyword 큐레이션부터 — 기존 소진, 신규 후보 작성 + dedup). 카테고리 분포 보정 지속(기타 비중↓).
- **Phase 7**: 자동화 loop (트리거 충족됨 — 사람 손 시간>5분). claude.ai 정액 vs API 전환 손익은 2B 비용 데이터 + Phase 6 누적으로 판단.

## 규칙 (CLAUDE.md / 사용자)

- 커밋: Conventional Commits, **scope 없이**, **Co-Authored-By 트레일러 금지**, 작성자 본인만.
- 진행 상태 정본은 디스크(ROADMAP·round 문서·spec). **메모리에 status 쓰지 말 것.**
- 전문가 에이전트엔 해답 박지 말고 문제·제약만 주고 진단·구현하게 할 것.
- iOS 빌드 시 이 워크트리엔 로컬 비밀파일(`Config.xcconfig`·`GoogleService-Info.plist`)이 없음 — 필요 시 더미로 빌드 통과(둘 다 gitignore). smoke는 BundleDBService 디코딩·검색 경로 결정론 검증으로도 충분.

## 가장 먼저 할 것

[`rounds/round-001.md`](rounds/round-001.md) 회고란을 읽고, **목표 N 산정안**(근거: round throughput·품질)을 사용자에게 제시해 확정받는다. 확정되면 spec Done 신호 갱신 → `critic-v2.md`·`scope_diff.py` 작성. (목표 N은 사람 결정 지점 — 단독 확정 금지.)
