# DevEtym Roadmap

DevEtym(개발 어원 사전) 중장기 작업 계획. 세부 실행 지시는 `spec.md`·`AGENTS.md`·각 ADR 문서를 참조.

---

## Now — 진행 중

_(번들 DB 확장 완료 → Done 이관. 현재 Now에 활성 작업 없음 — 다음 착수는 Next 참조.)_

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
- **[Ops/Security] API 키 온디바이스 제거 → 백엔드 프록시 + 호출 한도** — 출시 게이트(키 노출=비용 폭증 위험)
  - 결정: 원래 Claude API 키를 앱(Info.plist)에 넣을 계획이었으나, 출시 빌드는 디컴파일로 키 추출 가능 → 키 탈취·비용 폭증 위험. **키를 앱에 넣지 않고 얇은 백엔드 프록시로 전환** (앱 → 자체 서버 → Claude API, 키는 서버에만 보관)
  - 3층 방어:
    1. **(즉시)** Anthropic Console 월 spend 하드캡 설정 — 앱 코드와 무관한 최후 안전선. 다른 게 다 뚫려도 여기서 멈춤
    2. **(출시 전)** 백엔드 프록시로 온디바이스 키 제거. 클라이언트(앱) 카운터는 디컴파일로 우회되므로 비용 방어 불가 — 진짜 한도는 서버에서만 강제 가능
    3. 프록시에서 기기/사용자당 일일 호출 한도. AI 호출은 번들 DB(650개) 미스일 때만 발생 → 하루 3회는 신규 사용자가 탐색 중 조기 차단될 위험. **5~10회로 시작 후 실제 로그 보며 조정**
  - 의존: 없음. 출시 전 필수
- **[Ops] 출시 전 수동 작업 정리** — `AGENTS.md`의 "머지 후·출시 전 남은 수동 작업" 흡수
  - ~~GitHub Pages Source 활성화(`main /docs`)~~ → 완료. Pages는 GitHub Actions 워크플로로 `site/`만 발행 (2026-06-19)
  - Firebase DebugView 이벤트 수신 확인 (`-FIRDebugEnabled`)
  - `AppConfig.supportEmail` 실제 값 교체, `site/privacy-policy.md` 연락처 이메일 교체

---

## Later — 백로그 (아직 미착수, 검토 단계)

- **[Data] 번들 DB 추가 확장** — 출시 후 Firebase Analytics `search` 이벤트로 본 검색 빈도 데이터를 우선순위 입력으로 사용
- **[UI] 디자인 후속** — `docs/design/design-followup.md` 참조 (다크모드 헤더 경계·섹션 라벨 인식성·라이트모드 폴리시·accent 변형값 등)
- **[UX] 검색 UX 개선** — 자동완성 표시 정책·키워드 정규화 등 출시 후 사용 데이터 보고 결정
- **[Ops/Security] db-expand API 키 재발급** — 노출되어 폐기한 Anthropic API 키(`Scripts/db-expand/.env.local`) 재발급 필요. API 기반 확장·품질 재생성(Next [Data] 항목) 재개 시 필수. claude.ai 정액 수동 경로는 키 불필요.
- (아이디어 추가 시 여기로)

---

## Done — 완료

날짜·PR 번호는 git history 기준. 자세한 변경 내역은 각 PR 또는 관련 ADR 참조.

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
