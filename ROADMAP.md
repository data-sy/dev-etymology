# DevEtym Roadmap

DevEtym(개발 어원 사전) 중장기 작업 계획. 세부 실행 지시는 `spec.md`·`AGENTS.md`·각 ADR 문서를 참조.

---

## Now — 진행 중

### [Data] 번들 DB 출시 전 확장 (claude.ai batch) — `feat/bundle-db-pre-launch-expand`

- **목적:** launch 전 캐시된 번들 DB를 늘려 초기 사용자의 AI 호출 빈도·레이턴시 비용 감소.
- **방식:** claude.ai 2탭(Generator/Critic) batch 생성 → validator(코드) 결정론적 최종 검사 → `terms.json` 머지. 상세: [`docs/db-expand/spec.md`](docs/db-expand/spec.md) · 런북: [`docs/db-expand/runbook-manual-round.md`](docs/db-expand/runbook-manual-round.md).
- **진행 상태 (2026-06-19):** Phase 0 도구 완료. **round-001(10 keyword POC) 통과·커밋(`c0ee991`), `terms.json` 머지 전.** alias 룰 v2.1.1까지 개정(닫힌 목록→원칙 지배). 라운드 기록: [`docs/db-expand/rounds/round-001.md`](docs/db-expand/rounds/round-001.md).

#### 착수까지 준비 체크리스트 (→ Phase 6 본격 확장 직전까지)

> 태그: **[AI]** = Claude Code 실행 / **[사람]** = 당신만 가능(claude.ai 탭·Xcode·승인) / **[사람→AI]** = 당신이 열어주면 AI 실행

**A. round-001 마감** ✅ (Phase 7 자동화 판단 데이터 완성)
- [x] [사람] 사람 손 시간 ≈60분 기록 → **Phase 7 자동화 무조건 진행 결정**
- [x] [AI] `round-001.md` 갱신 완료

**B. Phase 2 일관성 점검** (머지 전 안전장치 — 통과 못 하면 Phase 1 회귀)
- [x] [AI] (A) 기존 `terms.json` 카테고리별 sample vs 신규 10개 비교 → `round-001-consistency-A.md` — **PASS** (3 gate 전부 통과, 2026-06-19)
- [x] [AI] (B) chat↔API drift: `api_sample.py`로 10개 API 재실행 비교 → `round-001-consistency-B.md` — **임계값 FAIL·원인 식별** (2026-06-19). API 단발이 길이 룰 비순응(validator 1/10); drift는 "critic 후 cycle-2 최종본 vs API 단발" 비대칭 + 단발 길이 초과. round-001 자체 무결. stale paste/지침 누락 아님.
- ⚠️ drift gate: **게이트 결정 미결** — (a) 원인 식별로 Done 인정→Phase 3 머지 / (b) API에 validator→재생성 루프 태운 공정 재검 / (c) Phase 1 회귀(비권장). 사람 결정 지점.

**C. Phase 3 머지 + iOS smoke test** (← 사람 승인 게이트)
- [x] [AI] `merge.py`로 `terms.next.json` 510개 생성 (충돌 0) → swap 적용(terms.json=510, 구 500은 terms.bak.json)
- [x] [AI] iOS smoke test **PASS** (2026-06-19, iPhone 17 시뮬레이터): 빌드·번들(510)·런치 크래시 없음·재시작 로딩 정상 + 신규 keyword/alias(한+영)/카테고리 검색(실제 swap 번들, BundleDBService 경로 결정론 확인). 빌드용 누락 비밀파일은 더미로 통과(gitignore).
- [x] [사람→AI] swap+커밋 완료 (`e11cf15` feat: 500→510, 기존 무손실·신규 10만 추가). terms.bak.json 정리됨. **번들 DB 510개로 갱신.**

**D. Phase 4 마감 결정** ✅ (다음 라운드 발주 — 사람 결정 지점)
- [x] [AI] 목표 N 산정안 제시 (round-001 throughput·품질 기준) — 분포 기준 600/650/700 3안
- [x] [사람] **목표 N = 650 확정** (2026-06-19) + Phase 5 critic-v2(정량 룰 제거) 진행
- [x] [AI] spec Done 신호 갱신(N=650), `prompts/critic-v2.md` + `scope_diff.py` 작성·기능검증(6/6)

**▶ 경계: Phase 6 — 30~50 keyword 확장 batch 시작** (여기부터 본 작업, 체크리스트 범위 밖)

**진행 상태 (2026-06-20):** 번들 DB **590개**. **round-003 종결·머지 완료** (550→590, 무손실 swap). 게이트 전부 PASS(validator 40/40 · critic-v2 0 fail · scope_leak 0 · dedup 완전매칭 0 · smoke). 분포: 자료구조 87·동시성 90·DB 92·네트워크 93·패턴 91·기타 137. ⭐ **critic 최초 고유 검출 1건**(split-horizon alias '수평 분할' 오역 — round-001·002 연속 0 깨짐, critic 유지 근거 확보). round-002 개선 3종 유효 확인(완전매칭 dedup·`*.paste.md` 격리·summary 하한 보정 → cycle1 39/40). 상세·측정·관찰: [`rounds/round-003.md`](docs/db-expand/rounds/round-003.md).

**Phase 7 방향 결정 (2026-06-20):** **자동화(API 전환) 보류 → claude.ai 정액 수동 유지.** claude.ai는 정액제(한계비용 0), API는 종량제. 잔여 +60은 수동으로 흡수 가능. 자동화가 사는 건 비용 아닌 사람 시간인데 잔여 규모가 작아 이득 < API 비용. **재검토 조건**: 출시 후 analytics 기반 대량 확장(수백 개) 시에만.

**다음 행동:** **수동 round-004로 590→650(+60).** 자료구조(87, 여전히 long pole, 목표 103까지 +16)·패턴 우선 보강, 기타 0. 흐름·게이트는 round-003과 동일(`Generator → validator → critic-v2 → 재생성 → scope_diff → 머지`, 완전매칭 dedup, `*.paste.md` 격리). 발주는 오케스트레이터가 round-004 발주안으로.

<details><summary>직전 (round-003 발주·실행)</summary>

**수동 round-003 발주·실행·머지(2026-06-20).** 발주안: [`rounds/round-003.md`](docs/db-expand/rounds/round-003.md). batch 40개(550→590), 코어 균등화 결손 비례. cycle1 validator 39/40(HAMT etymology 상한만 실패 — summary 미달 0, round-002 개선 효과). **critic 고유 검출 1건**(split-horizon '수평 분할' 오역, 3라운드 만의 첫 검출 → critic 유지 근거). balking은 generator가 동시성 분류(디자인 패턴으로 타당, 유지). round-002 개선 3종(완전매칭 dedup·paste 격리·summary 보정) 전부 유효 확인.
</details>

<details><summary>직전 (round-002 발주·실행)</summary>

**Phase 6 round-002 발주(2026-06-19)→실행·머지(2026-06-20).** 발주안: [`rounds/round-002.md`](docs/db-expand/rounds/round-002.md). batch 40개, 카테고리 결손 비례 배분. 흐름 `Generator → validator → critic(v2) → 재생성 → scope_diff → 머지` 첫 실통과. generator cycle 2회(cycle1 16/40 길이실패 → cycle2 24재생성 전부통과). critic-v2 고유검출 0(round-001도 0, 2연속). consistent-hashing 자료구조 확정(발주 DB→long pole 보강). alias 충돌: 구간 트리 제거(실충돌)/lazy loading 복원(false-positive). critic 격리 함정 1건(메모리 오염→임시챗 재실행).
</details>

<details><summary>직전 (Phase 4·5 마감)</summary>

**Phase 4 마감(2026-06-19)** — 목표 **N=650** 확정(현 510 → +140, 기타 제외 코어 동등화), spec Done 신호 갱신. Phase 5 산출물 완성: `critic-v2.md`(정량 룰 제거, nuanced 4종만) + `scope_diff.py`(scope leak 검출, 기능검증 통과). Phase 5 Done(흐름 실통과)은 Phase 6 첫 라운드에서 확인. 흐름 `Generator → validator → critic(v2) → 재생성 → scope_diff → 머지`. API 단발 길이 비순응은 Phase 7 loop(validator→재생성 필수) 근거로 흡수.
</details>

---

## Next — 다음 분기 (착수 예정)

- **[Ops/Docs] 독스 발행 범위 정리 + 내부 재정돈** — ✅ 완료 (2026-06-19).
  - 기존 문제: `docs/`가 Jekyll로 통째 발행 → 내부 문서 전부 공개 (Pages가 실제 라이브였음).
  - 발행: GitHub Actions 워크플로(`.github/workflows/pages.yml`)로 전환, **공개 전용 `site/`**(`index.md`·`privacy-policy.md`)만 발행. 차단-기본(default-deny) — `site/` 밖은 발행 안 됨. `docs/`는 순수 내부 문서함.
  - 내부 재정돈: `e2e-checklist.md`→`docs/`, 느슨한 설계 문서→`docs/design/`, stale 참조 정리(`CHECKLIST.md`·wireframe 경로), 임시 핸드오프(`handoff-docs-cleanup.md`) 삭제.
- **[UI] 검색 로딩 UI 개선 — 체감 latency 감소** — 새 브랜치 (예: `feat/loading-ui-perceived-latency`)
  - 목적: AI 호출 절대 latency 8s는 유지하되 *인지 길이*를 줄여 사용자 체감 개선. v2 라운드 시뮬레이터 테스트에서 latency가 핵심 UX 이슈로 확인됨
  - 적용 기법(조합):
    - **단계별 메시지** — "어원을 찾고 있어요" → "정리하고 있어요" → "마무리 중" 시간 분할 인지
    - **skeleton placeholder** — 어원·작명 이유 영역 회색 박스로 결과 도착 위치 미리 표시
    - **진행감 애니메이션** — 정적 spinner 대신 dot pulse·progress 채움 등 변화 있는 모션
    - **최소 표시 시간 300~500ms** — 캐시 hit 시 플래시 방지
    - **명시적 정당화 텍스트** — "AI가 분석 중" 등 *왜 기다리는지* 설명
  - 영향 범위: `SearchView`·`DetailView`의 loading state. 디자인 시스템 컬러·폰트 토큰 재사용
  - 의존: 없음 (v2 PR 머지 후 별도 진행 가능). 번들 DB 확장과 병행 가능
- **[Data] 번들 DB 기존 200개 품질 재생성** — `AGENTS.md` backlog 참조
  - 신규 300개는 개선 프롬프트로 생성됐으나 기존 200개는 구 프롬프트 결과 잔존 → 톤 일관성 보강
  - 절차: 샘플 10~15개 재생성 비교(~$0.20) → 체감되면 전체(~$2) → 미미하면 스킵
  - 크레딧: 충전됨 (2026-06-19, ~$195 보유) — 재개 가능. (claude.ai batch로 대체 가능 여부도 검토)
- **[Ops] 출시 전 수동 작업 정리** — `AGENTS.md`의 "머지 후·출시 전 남은 수동 작업" 흡수
  - ~~GitHub Pages Source 활성화(`main /docs`)~~ → 완료. Pages는 GitHub Actions 워크플로로 `site/`만 발행 (2026-06-19)
  - Firebase DebugView 이벤트 수신 확인 (`-FIRDebugEnabled`)
  - `AppConfig.supportEmail` 실제 값 교체, `site/privacy-policy.md` 연락처 이메일 교체

---

## Later — 백로그 (아직 미착수, 검토 단계)

- **[Data] 번들 DB 추가 확장** — 출시 후 Firebase Analytics `search` 이벤트로 본 검색 빈도 데이터를 우선순위 입력으로 사용
- **[UI] 디자인 후속** — `docs/design/design-followup.md` 참조 (다크모드 헤더 경계·섹션 라벨 인식성·라이트모드 폴리시·accent 변형값 등)
- **[UX] 검색 UX 개선** — 자동완성 표시 정책·키워드 정규화 등 출시 후 사용 데이터 보고 결정
- (아이디어 추가 시 여기로)

---

## Done — 완료

날짜·PR 번호는 git history 기준. 자세한 변경 내역은 각 PR 또는 관련 ADR 참조.

- **AI 시스템 프롬프트 v2 라운드** — 2026-05-13~16 (PR 준비 중)
  - **Path A 채택**: `alias_strict` 처방 + `null guard` ([도구 선택] 본문)
  - **명시적 비채택**: `closing`·`selfcheck`는 MVP latency·cost 부담으로 v3 카드 — launch 후 retention 데이터 보고 재검토
  - 측정 인프라: factorial probe 도구(`Scripts/prompt-probe/`) — closing × selfcheck × alias_strict 직교성 검증
  - acceptance probe(1-cell × 15 keyword, 2026-05-16_0049 run): 차단 조건 6/6 통과, `null` 분기 회귀 정상화 확인
  - 상세: `docs/ai-quality/probe-analysis-v2.md`(§7·§8 의사결정 흐름), `docs/ai-quality/handoff-v2.md`(반영 지시서)
  - 후속: ADR로 `handoff-v2.md` 흡수 권장
- **타이포그래피 마무리** — 2026-04-30 (PR [#17](https://github.com/data-sy/dev-etymology/pull/17), [#18](https://github.com/data-sy/dev-etymology/pull/18))
- **Analytics + 데이터 수집 동의 + AppConfig 분리** — 2026-04-29 (PR [#16](https://github.com/data-sy/dev-etymology/pull/16))
  - Firebase Analytics 연동, PIPA 동의 온보딩, 설정 탭 데이터 수집 섹션, 외부 접점 `AppConfig`로 분리
  - 상세: `AGENTS.md` "analytics — 완료" 섹션
- **앱 아이콘 · 런치 스크린** — 2026-04-23 (PR [#14](https://github.com/data-sy/dev-etymology/pull/14), [#15](https://github.com/data-sy/dev-etymology/pull/15))
- **번들 DB 300개 확장 + AI 품질 v1 라운드** — 2026-04-20~21 (PR [#11](https://github.com/data-sy/dev-etymology/pull/11), [#12](https://github.com/data-sy/dev-etymology/pull/12), [#13](https://github.com/data-sy/dev-etymology/pull/13))
  - 시스템 프롬프트 v1 리비전 + 번들 DB 신규 300개 생성 + ai-quality 인프라
  - 후속: ADR로 `handoff-v1.md` 흡수 권장
- **초기 골격 + UI 디자인 + 설정 탭** — 2026-04-16~17 (PR [#1](https://github.com/data-sy/dev-etymology/pull/1)~[#10](https://github.com/data-sy/dev-etymology/pull/10))
  - SwiftData 모델 · TermService 오케스트레이션 · 번들 DB · 검색/북마크/히스토리 UI · 디자인 시스템 · 설정 탭 · 다중 에이전트 분배 체계

---

## 작업 단위 분할 원칙

DevEtym은 비교적 작은 단일 앱이라 math-teacher 식 풀구조(Roadmap → Epic → Milestone → Spec → ADR)는 도입하지 않고 가벼운 변형을 사용한다.

- **Roadmap** — 모든 작업의 단일 인덱스 (이 문서)
- **Spec** — `spec.md` 단일 파일이 v1 출시 시점의 구현 명세를 보존. 새 큰 작업이 생기면 `docs/specs/` 도입 검토
- **AGENTS.md** — 영역별 에이전트(services/data/ui/settings/ai) 책임 분배 + 백로그 누적
- **ADR** — 돌이킬 수 없는 의사결정(프롬프트 라운드, 데이터 모델 변경, 아키텍처 결정 등) 기록 (`docs/adr/`)
- **handoff-*.md** — AI 프롬프트 라운드 결과는 `docs/ai-quality/handoff-vN.md`로 별도 보존하고 ADR에서 참조

## 갱신 규칙

- 새 작업 착수 시 Now로 이동, 관련 브랜치명 함께 기록
- 완료 시 Done으로 이동, 완료일·PR 번호 기록. 의사결정이 있었다면 ADR 번호도 함께
- 새 아이디어는 Later에 먼저 추가하고, 우선순위가 올라가면 Next로 승격
- 보류된 작업은 Next에 두고 "보류 사유" 명시
