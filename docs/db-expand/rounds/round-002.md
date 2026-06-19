# 라운드 002 — 발주 (Phase 6 본 확장, 오케스트레이터 작성)

> **상태: 발주됨 (2026-06-19). 실행 대기.** 이 문서는 오케스트레이터가 작성한 *발주안*이다.
> 실행 세션이 `handoff-phase6.md` + 이 발주안으로 굴린 뒤, 아래 "라운드 결과"·"오케스트레이터 결정 필요" 섹션을 채운다.
> 진행 상태 정본은 디스크 — 충돌 시 `ROADMAP.md` "Now" · `spec.md` · 이 문서를 신뢰.

## 성격 (왜 이 라운드인가)

- **마지막 수동 라운드**(handoff 전제). 목표는 "650 수동 도달"이 아니라:
  1. **Phase 5 Done 충족** — 새 흐름 `Generator → validator → critic(v2) → 재생성 → scope_diff → 머지`를 실제로 통과시킨다.
  2. **Phase 7 판단 데이터 확보** — 통과율·평균 재시도·사람 손 시간·2B 샘플 API 비용/latency·critic-v2 고유 검출 추이.
- 나머지 +100(550→650)은 Phase 7 자동화 loop로 흡수.

## 발주 범위 (사람 확정 2026-06-19)

- **batch size: 40** (510 → 550)
- **카테고리 배분 — 결손(→100) 비례, 기타 0:**

| 카테고리 | 현재 | 신규 | 도달 |
|---|---|---|---|
| 자료구조 (long pole) | 64 | **+11** | 75 |
| 동시성 | 71 | **+9** | 80 |
| 네트워크 | 79 | **+7** | 86 |
| 패턴 | 79 | **+7** | 86 |
| DB | 80 | **+6** | 86 |
| 기타 | 137 | 0 | 137 |
| **합** | 510 | **+40** | **550** |

- 배분 근거: 결손 합 +127(자료구조 36·동시성 29·네트워크 21·패턴 21·DB 20)에 비례. 자료구조·동시성 가중으로 long pole 우선 축소.

## 수용 게이트 (spec 고정 + 이 라운드 적용)

1. **validator 100%** — 길이(summary 20~30 / etymology 60~120 / namingReason 150~270) · 카테고리 enum · null guard · keyword 형식 · alias 최소1 + 한글 alias 최소1 · keyword 유니크. 신규 batch 전용(머지 산출물엔 미적용, legacy grandfather).
2. **critic-v2 통과** — nuanced 4종(ALIAS_STRICT 의미판단 · ETYMOLOGY_FACT · NAMING_COHERENCE · NAMING_CLOSING). 정량 룰은 critic에서 제거됨(validator 단일 정본).
3. **scope_diff: scope_leak 0** — 재생성이 있었으면 `python scope_diff.py before.json after.json <failed_keywords>` 로 확인. clean exit 0.
4. **dedup** — 기존 `terms.json`(510)의 `{keyword}` ∪ `{모든 alias}` 차집합. array 내 keyword 중복 0.
5. **분포 보정** — 신규 기타 0, 코어 동등화 방향 일치(위 표대로).
6. **비가역 게이트** — `terms.next.json` swap·머지 커밋은 iOS smoke 통과 후 **사람 승인**.

## 실행 흐름 (handoff-phase6.md 착수 순서)

1. [AI] `Scripts/db-expand/keywords-round-002.txt` 큐레이션 — 위 배분대로 40개, 코어 위주(자료구조 보강), 기타 0.
2. [AI] dedup (게이트 4).
3. [사람] 2탭 실행 — A=`prompts/v2-batch.md`, B=`prompts/critic-v2.md`. Generator → validator(정량 1차) → critic(v2) → 재생성(최대 3회) → 통과.
4. [AI] scope_diff (게이트 3).
5. [AI] merge + iOS smoke → 사람 승인 후 swap·커밋 (게이트 6).
6. [AI] 이 문서 "라운드 결과" 채움 + "오케스트레이터 결정 필요" 섹션.

## 측정 (라운드별 누적 — Phase 7 입력)

- 최종 통과율 / 평균 재시도 횟수 / 라운드당 사람 손 시간 / 2B 샘플 항목당 API 비용·latency.
- critic-v2 고유 검출 추이(round-001 = 0). 계속 0이면 critic 추가 축소/제거 신호.
- 길이 카운팅 오차 누적(round-001 표본 작아 신호 약함).

## 미결/이월 (오케스트레이터 추적)

- **Phase 2B drift 게이트 결정**: round-001.md는 "게이트 결정 미결"로 남았으나 실제로는 결정 (a)(원인 식별 = Done 인정)로 머지·커밋(`e11cf15`)됨. round-001은 종결이라 회귀 사유 아님 — 기록 일관성 차원의 이월만. Phase 7 loop 설계 시 "API 단발 길이 비순응 → validator→재생성 필수"가 정본 근거.

---

## 라운드 결과 (실행 세션이 채움)

> (미실행)

## 오케스트레이터 결정 필요 (실행 세션이 채움)

> (미실행)
