## 라운드 001 — 2026-06-19 (Phase 1 POC)

- batch size: 10
- keyword 리스트: priority-inversion, aba-problem, merkle-tree, persistent-data-structure, sni, hsts, sharding, materialized-view, command-pattern, aggregate-root
- Generator 라운드 수: 2 (cycle 1 생성 → cycle 2 재생성)
- 최종 통과율: 10/10
- 라운드당 사람 손 시간: ≈60분 (어림치). **결정: Phase 7 자동화 무조건 진행 예정** — 트리거(>5분) 충족, 정밀 측정 불요.
- API 비용·latency (Phase 2B 샘플): 10 keyword 1회 호출 (input 11~수천 토큰 / 출력 1배치), 단발. 상세 round-001-consistency-B-api.json.
- 일관성 점검: (A) **PASS** (`round-001-consistency-A.md`) / (B) **임계값 FAIL·원인 식별** (`round-001-consistency-B.md`, 2026-06-19) — API 단발은 길이 룰 비순응(validator 1/10), drift는 "루프 최종본 vs 단발" 비대칭 + 단발 길이 초과. round-001 자체는 무결. 게이트 결정 미결(머지 vs 공정 재검).

### 검증 결과
- **validator (결정론적, 최종 게이트)**: 10/10 통과 (`failed: []`). 길이·카테고리·null·alias 최소·keyword 형식 전부 통과.
- **critic (critic-v1, v2.1.1 룰)**: 10/10 통과. nuanced 경계 케이스 3건을 올바르게 통과 처리:
  - merkle-tree `hash tree` → RULE_ALIAS_STRICT (5) 다른 언어 정식 동의어
  - hsts `HTTP Strict Transport Security` → 통과 예 (2) 약어 풀네임 (한정수식어 변형 아님)
  - aggregate-root `루트 엔티티` → DDD 통용 정식 명칭, 통과 예 (5)

### critic 고유 검출 = 0 (Phase 5 축소 근거)
- 이 배치(cycle 2)에서 critic이 validator 외 유니크하게 잡은 nuanced 품질 문제: **0건**.
- cycle 1에서 critic이 잡은 2건의 성격:
  - priority-inversion 길이(etymology 125>120) → **validator와 overlap** (정량 룰, critic 고유 아님). 단 해당 cycle은 validator 미실행이라 overlap 안전망이 실제로 작동한 사례로 기록.
  - merkle-tree alias → **critic 유니크였으나 룰 결함발 false-positive** (닫힌 화이트리스트 ∧ 원칙 충돌). 품질 검출이 아니라 룰 버그. v2.1.1로 해소.
- → 결론: nuanced 룰의 실질 검출 0. **critic-v2에서 정량 룰 제거(validator 단일 정본화) 근거 데이터 확보.**

### 길이 카운팅 오차 (critic)
- critic이 cycle 2에서 "정량 통과"로 판정 → validator도 동일하게 통과. 이번 라운드에선 critic의 길이 판정과 코드 카운트 불일치 없음.
- 단 cycle 1의 priority-inversion(125자)은 critic이 정확히 셌음. 표본이 작아 "LLM 한글 카운팅 약점"의 강한 신호는 아직 없음 — Phase 6에서 누적 관찰.

### Scope leak
- 0건. cycle 2 재생성에서 priority-inversion etymology만 변경, 나머지 9개 원문 유지 확인 (눈 + 비교).

### 분포
- 카테고리: 동시성 2 / 자료구조 2 / 네트워크 2 / DB 2 / 패턴 2 / **기타 0** — 의도한 분포 보정(기타 137 편중 회피) 달성.
- 길이 평균: summary 23.5 (21~25) / etymology 100.9 (89~117) / namingReason 199.3 (176~228) — 전부 규약 내, 하한·상한 여유 있음.
- alias 개수: 중앙값 2 (범위 1~3).

### alias 룰 개정 경위 (이 라운드에서 2회)
- **v2.1**: MIN1(한글 alias 필수) ∧ STRICT(번역 금지)가 음차 없는 용어에서 충족 불가 모순. → (4) 정착된 한국어 이름 추가, 축을 "이름이냐 설명이냐"로. (cycle 1 critic 결과)
- **v2.1.1**: 닫힌 화이트리스트("4범주 중 하나에만")가 위 원칙과 충돌 — merkle "hash tree" 같은 정식 영어 동의어가 4범주 밖. → 목록을 예시로 강등, 원칙 지배, (5) 다른 언어 정식 동의어 허용. (cycle 1→재심사 사이)

### 관찰
- 2탭(Generator/Critic) 분리가 룰셋 모순을 잡아낸 것이 이 POC의 최대 수확 — entry 품질이 아니라 룰 설계 결함을 노출.
- generator는 closing 룰(마지막 문장 새 정보)을 10개 모두 준수. few-shot(jpa) closing 위반은 v2.1에서 교체 완료.

### 다음 라운드 변경 후보
1. **critic-v2 (Phase 5)**: 정량 룰 전부 제거, nuanced 룰(ALIAS_STRICT 의미판단·ETYMOLOGY_FACT·NAMING_COHERENCE)만 유지. 근거: 이 라운드 critic 고유 검출 0.
2. **Phase 2 일관성 점검** 먼저 수행 (기존 terms.json sample 베이스라인 비교 A + chat↔API drift B) 후 머지.
3. **목표 N 결정**: round당 throughput(생성 2 cycle, 사람 손 시간 TBD) 기준 출시 전 도달 가능 N 산정 → spec Done 신호 갱신.

### 상태
- [x] round-001.json 저장 + validator 통과
- [x] 사람 손 시간 기록 (≈60분, 자동화 진행 결정)
- [x] Phase 2A 일관성 점검 (기존 sample 베이스라인) — PASS (`round-001-consistency-A.md`)
- [x] Phase 2B 일관성 점검 (chat↔API drift) — 실행 완료. 임계값 FAIL이나 **drift 원인 식별**(spec Done 후자 충족). `round-001-consistency-B.md`. 게이트 결정 미결.
- [x] Phase 3 머지 — `merge.py`로 `terms.next.json` 510개(500+10) 생성, 충돌 0, 정렬·유니크·스키마 OK
- [x] Phase 3 iOS smoke test — **PASS** (2026-06-19, iPhone 17 시뮬레이터). 빌드 성공·terms.json(510) 번들·런치 크래시 없음·재시작 로딩 정상. 신규 keyword/alias(한+영)/카테고리 검색은 실제 swap 번들에 대해 BundleDBService 경로로 결정론 확인. (워크트리 누락 비밀파일 Config.xcconfig·GoogleService-Info.plist는 더미로 빌드 통과, gitignore라 커밋 제외.)
- [x] terms.json swap 커밋 (비가역) — 완료 (`e11cf15` feat: 500→510). round-001 라운드 종결.
