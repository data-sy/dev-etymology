# DevEtym Roadmap

DevEtym(개발 어원 사전) 중장기 작업 계획. 세부 실행 지시는 `spec.md`·`AGENTS.md`·각 ADR 문서를 참조.

---

## Now — 진행 중

_(없음 — v2 라운드 완료. 다음 차례는 Next에서 승격)_

---

## Next — 다음 분기 (착수 예정)

- **[Data] 번들 DB 출시 전 확장 (claude.ai batch)** — 새 브랜치 (예: `feat/bundle-db-pre-launch-expand`)
  - 목적: launch 전 캐시된 번들 DB 양 늘려서 초기 사용자의 AI 호출 빈도·레이턴시 비용 감소
  - 방식: **claude.ai 대화창 사용** (요금제 내 처리, API 비용 우회). v2 production 시스템 프롬프트(`ClaudeAPIService.swift` 또는 `Scripts/prompt-probe`)를 system message로 깔고 batch JSON 받기. tool_use 강제 못 하므로 사용자 메시지에 "필드명·카테고리 enum·길이 기준 엄수" 명시
  - 검증 게이트: 카테고리 ∈ {동시성, 자료구조, 네트워크, DB, 패턴, 기타} · 필드 길이(summary 20~30 / etymology 60~120 / namingReason 150~270) · alias_strict 룰(한정 수식어 없음). 자동 validator 스크립트 도입 권장
  - 선택: claude.ai vs API 일관성 비교 실험 10 keyword (~$0.05·30분) — 톤 차이 실측 후 본격 batch 결정
  - 의존: v2 PR 머지 (claude.ai에 깔 시스템 프롬프트가 v2 production이어야 함)
- **[Data] 번들 DB 기존 200개 품질 재생성** — `AGENTS.md` backlog 참조
  - 신규 300개는 개선 프롬프트로 생성됐으나 기존 200개는 구 프롬프트 결과 잔존 → 톤 일관성 보강
  - 절차: 샘플 10~15개 재생성 비교(~$0.20) → 체감되면 전체(~$2) → 미미하면 스킵
  - 보류 사유: Anthropic API 크레딧 소진(2026-04-21). 충전 후 재개. (위 출시 전 확장과 같이 claude.ai로 대체 가능 검토)
- **[Ops] 출시 전 수동 작업 정리** — `AGENTS.md`의 "머지 후·출시 전 남은 수동 작업" 흡수
  - GitHub Pages Source 활성화(`main /docs`)
  - Firebase DebugView 이벤트 수신 확인 (`-FIRDebugEnabled`)
  - `AppConfig.supportEmail` 실제 값 교체, `docs/privacy-policy.md` 연락처 이메일 교체

---

## Later — 백로그 (아직 미착수, 검토 단계)

- **[Data] 번들 DB 추가 확장** — 출시 후 Firebase Analytics `search` 이벤트로 본 검색 빈도 데이터를 우선순위 입력으로 사용
- **[UI] 디자인 후속** — `docs/design-followup.md` 참조 (다크모드 헤더 경계·섹션 라벨 인식성·라이트모드 폴리시·accent 변형값 등)
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
