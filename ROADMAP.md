# DevEtym Roadmap

DevEtym(개발 어원 사전) 중장기 작업 계획. 세부 실행 지시는 `docs/specs/spec.md`·각 ADR 문서를 참조.

---

## Now — 진행 중

_(번들 DB 확장 완료 → Done 이관. 현재 Now에 활성 작업 없음 — 다음 착수는 Next 참조.)_

---

## Next — 다음 분기 (착수 예정)

- **[Ops/Docs] 독스 발행 범위 정리 + 내부 재정돈** — ✅ 완료 (2026-06-19).
  - 기존 문제: `docs/`가 Jekyll로 통째 발행 → 내부 문서 전부 공개 (Pages가 실제 라이브였음).
  - 발행: GitHub Actions 워크플로(`.github/workflows/pages.yml`)로 전환, **공개 전용 `site/`**(`index.md`·`privacy-policy.md`)만 발행. 차단-기본(default-deny) — `site/` 밖은 발행 안 됨. `docs/`는 순수 내부 문서함.
  - 내부 재정돈: `e2e-checklist.md`→`docs/`, 느슨한 설계 문서→`docs/design/`, stale 참조 정리(`CHECKLIST.md`·wireframe 경로), 임시 핸드오프(`handoff-docs-cleanup.md`) 삭제.
- **[Data] 번들 DB 기존 200개 품질 재생성**
  - 신규 300개는 개선 프롬프트로 생성됐으나 기존 200개는 구 프롬프트 결과 잔존 → 톤 일관성 보강
  - 절차: 샘플 10~15개 재생성 비교(~$0.20) → 체감되면 전체(~$2) → 미미하면 스킵
  - 크레딧: 충전됨 (2026-06-19, ~$195 보유) — 재개 가능. (claude.ai batch로 대체 가능 여부도 검토)
- **[Ops] 출시 준비 (Launch Prep)** — 출시(v1.0)에 필요한 작업 허브. 외부 접점·App Store 메타데이터·서명·QA 등.
  - 상세 체크리스트·완료 기준: [`docs/launch-prep.md`](docs/launch-prep.md) (A 외부접점·계측 / B 메타데이터 / C 빌드·서명·컴플라이언스 / D 백엔드 운영화 / E 데이터 / F QA 게이트)
  - **진행 상태 정본은 본 항목**(launch-prep는 스펙만 보유).
  - 진행: A 외부접점 — 지원 이메일 `oddmuffinstudio@gmail.com` 확정·교체 완료(A-1·A-2). **다음: A-3 Firebase DebugView 확인 / B App Store 메타데이터.**
  - 일부 완료: GitHub Pages 발행(`site/`만, 2026-06-19) / 백엔드 운영화(D) 중 ① Console 하드캡·키 회전(분기).

---

## Later — 백로그 (아직 미착수, 검토 단계)

- **[Data] 번들 DB 추가 확장** — 출시 후 Firebase Analytics `search` 이벤트로 본 검색 빈도 데이터를 우선순위 입력으로 사용
- **[UI] 디자인 후속** — `docs/design/design-followup.md` 참조 (다크모드 헤더 경계·섹션 라벨 인식성·라이트모드 폴리시·accent 변형값 등)
- **[UX] 검색 UX 개선** — 자동완성 표시 정책·키워드 정규화 등 출시 후 사용 데이터 보고 결정
- **[Ops/Security] db-expand API 키 재발급** — 노출되어 폐기한 Anthropic API 키(`Scripts/db-expand/.env.local`) 재발급 필요. API 기반 확장·품질 재생성(Next [Data] 항목) 재개 시 필수. claude.ai 정액 수동 경로는 키 불필요.
- **[UI/Data] AI 결과 나열 항목 줄바꿈** — AI 생성 결과에서 "첫째/둘째/셋째" 같은 나열이 줄바꿈 없이 한 문단으로 이어져 가독성 저하 (실측: `handoff` 상세 — 번들 아닌 SwiftData 캐시된 AI 결과). 비출시 영향
  - 렌더링은 공짜: SwiftUI `Text`가 `\n` 줄바꿈을 그대로 표시(어원/작명이유에 `.fixedSize` 이미 적용). 핵심은 *어디서 끊나*
  - 주의: 현재 번들 데이터의 "첫째/세 번째" 등은 전부 **문장 속 산문**(예: `primarius(첫째의)`, `세 번째 수준으로`)이라 마커 앞 무조건 줄바꿈하면 문장이 잘림 → 휴리스틱은 마커가 문두/구두점 뒤일 때만 끊도록 제한 필요
  - 옵션: (a) AI 출력에 한해 안전한 줄바꿈 휴리스틱 (b) 프롬프트에서 나열 시 줄바꿈/리스트로 출력하도록 지시 — DB 재생성과 묶임
- (아이디어 추가 시 여기로)

---

## Done — 완료

날짜·PR 번호는 git history 기준. 자세한 변경 내역은 각 PR 또는 관련 ADR 참조.

- **[Ops/Security] API 키 온디바이스 제거 → 백엔드 프록시 + 호출 한도** — 2026-06-23 (PR [#26](https://github.com/data-sy/dev-etymology/pull/26))
  - 앱에서 Anthropic 키 완전 제거(클린 빌드 바이너리 `sk-ant`/`CLAUDE_API_KEY` 0건), 모든 Claude 호출을 얇은 프록시 경유. 키는 프록시 서버 시크릿에만.
  - 플랫폼 **Cloudflare Workers + KV**, 기기당 일일 한도 **10회**(서버 강제, 초과 시 429 → 앱 "오늘 한도" 안내). 결정 근거: [ADR-0001](adr/0001-backend-proxy-hosting.md).
  - 백엔드 별도 repo `devetym-proxy`(비공개). 3층 방어 전부 검증(① Console 월 하드캡 / ② 키 부재 / ③ 한도 429). 키 회전 = 분기 1회.
  - 남은 운영화(모니터링·한도 조정)는 Next `[Ops] 출시 준비` D로 이관.
- **[UI] 검색창 하단 재배치 — 한 손 도달성** — 2026-06-22 (브랜치 `feat/search-bar-bottom-placement`)
  - **A안 구현**: 검색필드를 `safeAreaInset(.bottom)`로 하단 고정(키보드 위 자동 회피 ⓑ), 최근검색 칩을 필드 바로 위로, 자동완성은 `defaultScrollAnchor(.bottom)`로 위로 펼침(ⓐ). 입력 중 탭바는 키보드가 자연히 덮어 수동 숨김 불필요(ⓒ 해소).
  - 헤더는 hero(DM Serif 28) 좌상단 고정 — 필드를 inset으로 빼며 생긴 센터링 부작용 제거 + 탭바↔필드 간격·수직 리듬 개선. 시안: `docs/design/search-header-spacing-mockup.html`(B/C/D 비교, 전부 C 채택).
  - 검증: iPhone 17 Pro 시뮬 + iPhone 13 mini 실기 — 평상시/자동완성/키보드회피/대형 Dynamic Type 확인.
- **docs/ IA 전면 재설계 + 저장소 정돈** — 2026-06-22
  - 영역(주제) 기반 IA 채택(수명주기 기반 기각 — 완료 시 이동 노동·링크 깨짐). 조직 원칙은 findability·무상태·일회용 핸드오프로 정립(범용 원칙문서 `ia-conventions.md`는 저장소 밖 보관).
  - 이동: `spec.md`→`docs/specs/`, `docs/icon`·`docs/wireframe`·떠다니던 목업 → `docs/design/`(wireframe v1 삭제, v2→`wireframe.html`). 결과 `docs/`는 `adr·ai-quality·db-expand·design·handoff` + `e2e-checklist.md`.
  - 삭제: `AGENTS.md`(ROADMAP·CLAUDE와 중복, 출시 체크리스트는 `h3`가 이미 보존), `Scripts/`의 소진된 keyword 파일 2개. 하드코딩 참조 일괄 갱신(README·spec·ROADMAP·ux-design 에이전트·h4), 깨진 링크 0.
  - `docs/README.md` 인덱스 신설. 핸드오프 컨벤션: `docs/handoff/`는 일회용(작업 완료 시 삭제).
- **검색 로딩 UI 개선 — 체감 latency 감소** — 2026-06-21 (PR [#23](https://github.com/data-sy/dev-etymology/pull/23))
  - **B 중앙 집중형 채택** (시안 A 스켈레톤형 대비): 단계별 메시지(찾는 중→정리 중→마무리) · dot pulse 애니메이션 · 최소 표시 시간 ~350ms(캐시 hit 깜빡임 방지) · 정당화 텍스트
  - **남은 시간 숫자(8초) 미표기** 결정 — 기대치 박으면 더 길게 느껴지고 초과 시 고장처럼 보임
  - `DetailViewModel`에 `LoadingPhase` 진행/최소 표시 시간 로직 + 테스트 6종. 시안 보존: `docs/design/loading-ui-mockup.html`
- **번들 DB 출시 전 확장 (500→650)** — 2026-06-20 (PR [#21](https://github.com/data-sy/dev-etymology/pull/21))
  - claude.ai 2탭(Generator/Critic) batch 생성 + 결정론 코드 게이트(validator·critic-v2·scope_diff·merge·smoke) 파이프라인. round-001~004 무손실 확장, 코어 5개 카테고리 균등화(자료구조·동시성·패턴 103 / DB·네트워크 102 / 기타 137). 기타 비중 27%→21%.
  - 결정: 목표 N=650 / Phase 7 자동화 미진입(claude.ai 정액 수동 유지, API 종량 회피) / dedup 완전매칭. 추가 확장은 출시 후 Firebase Analytics 검색 빈도 기반(Later).
  - 문서함: `docs/db-expand/`(spec·rounds·runbook·archive·README). 상세: [`rounds/round-004.md`](docs/db-expand/rounds/round-004.md).

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
  - 상세: git history (`feat/analytics`, PR [#16](https://github.com/data-sy/dev-etymology/pull/16))
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
- **Spec** — `docs/specs/spec.md`가 v1 출시 시점의 구현 명세를 보존
- **ADR** — 돌이킬 수 없는 의사결정(프롬프트 라운드, 데이터 모델 변경, 아키텍처 결정 등) 기록 (`docs/adr/`)
- **handoff** — `docs/handoff/`의 일회용 인수인계 문서. 해당 작업 완료 시 삭제(진행상태 정본은 이 Roadmap). AI 프롬프트 라운드 기록은 `docs/ai-quality/`에 보존하고 ADR로 흡수

## 갱신 규칙

- 새 작업 착수 시 Now로 이동, 관련 브랜치명 함께 기록
- 완료 시 Done으로 이동, 완료일·PR 번호 기록. 의사결정이 있었다면 ADR 번호도 함께
- 새 아이디어는 Later에 먼저 추가하고, 우선순위가 올라가면 Next로 승격
- 보류된 작업은 Next에 두고 "보류 사유" 명시
