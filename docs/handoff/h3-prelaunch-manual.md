# 핸드오프 H3 — 출시 전 수동 작업 정리

작성 세션: 오케스트레이션 세션 2026-06-21. 실행: 별도 세션(단발 + 사람 트리거).
정본 상태는 `ROADMAP.md`의 "Next > [Ops] 출시 전 수동 작업 정리"에 기록한다(이 문서 아닌 ROADMAP이 진행상태 정본).

## 문제 / 목적

출시 게이트인 외부 접점 플레이스홀더와 미검증 계측을 출시 전에 실제 값·검증으로 교체한다.
근거: `ROADMAP.md` Next > [Ops] 출시 전 수동 작업 정리.

## 완료 조건 (3건 모두 충족)

1. **Firebase DebugView 이벤트 수신 확인**
   - Scheme launch argument에 `-FIRDebugEnabled` 추가한 빌드로 실제 검색을 실행하고, Firebase DebugView에 `search`·오류 이벤트 등이 도달하는지 눈으로 확인.
   - 완료 기준: 주요 Analytics 이벤트가 DebugView에 실제로 찍히는 스크린샷/기록. 안 찍히면 원인(이벤트 미발화 vs 설정) 분리해 기록.

2. **`AppConfig.supportEmail` 실제 값 교체**
   - 현재 `DevEtym/DevEtym/Utils/AppConfig.swift`에 `supportEmail = "devetym@gmail.com"` + `// TODO(이메일)` 플레이스홀더.
   - 사용자에게 실제 지원 이메일을 받아 교체. **값 자체는 사용자 결정** — 임의로 정하지 말 것.
   - 점검: `grep -rn "TODO(" DevEtym docs` 가 이메일 항목에서 깨끗해야 함.

3. **개인정보 처리방침 연락처 이메일 교체**
   - `site/privacy-policy.md`의 연락처 이메일을 위 2번과 동일 값으로 교체(불일치 금지).
   - `site/`는 공개 발행 대상이므로 교체 후 발행 워크플로(`.github/workflows/pages.yml`) 영향 없는지 확인.

## 제약

- 이메일 값은 사용자가 제공. 받기 전엔 교체 작업을 막고 사용자에게 요청.
- `site/` 외 파일을 공개 발행 영역으로 옮기지 말 것(default-deny 유지).

## 참조
- `DevEtym/DevEtym/Utils/AppConfig.swift`
- `site/privacy-policy.md`
- `docs/e2e-checklist.md`
