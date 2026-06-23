# 출시 준비 (Launch Prep)

DevEtym v1.0 출시에 필요한 작업 허브. 외부 접점·메타데이터·서명·QA 등 출시에 걸리는 모든 항목을 모은다.

> **진행 상태 정본은 `ROADMAP.md`의 `[Ops] 출시 준비` 항목.** 이 문서는 *각 항목의 정의·완료 기준·주체*를 보유한다(상태가 아니라 스펙). 출시 완료 시 보관/삭제.
>
> 주체 태그: **[사람]** = 계정·브라우저·결정 필요 / **[AI]** = 코드·문서로 처리 / **[사람→AI]** = 값/승인 받으면 AI가 실행

## A. 외부 접점·계측
- **[사람]** 우산 지원 이메일 확정 — 모든 앱 공용 단일 Gmail(공개 주소). 2FA 필수, 앱별 분류는 제목 필터로.
- **[사람→AI]** `AppConfig.supportEmail` + `site/privacy-policy.md` 연락처를 **동일 값**으로 교체(불일치 금지). 점검: `grep -rn "TODO(" DevEtym docs`가 이메일 항목에서 깨끗.
- **[사람/AI]** Firebase DebugView 이벤트 수신 확인 — `-FIRDebugEnabled` 빌드로 실검색 → `search`·오류 이벤트 도달 확인.

## B. App Store Connect 메타데이터
- **[사람→AI]** 앱 이름·부제·설명·키워드·카테고리·프로모션 텍스트 (카피는 AI 초안 가능, 최종 결정 사람).
- **[사람]** 스크린샷(필수 사이즈) · 앱 아이콘 최종 · 지원/마케팅 URL.
- **[사람]** 연령 등급 설문 · **개인정보 라벨**(수집 항목: Firebase Analytics 이벤트, 익명 기기ID).

## C. 빌드·서명·컴플라이언스
- **[사람/AI]** 버전/빌드 번호(1.0) 설정.
- **[사람]** Export compliance — HTTPS만 사용 → 보통 면제. `ITSAppUsesNonExemptEncryption` 선언.
- **[사람]** Distribution 서명·프로비저닝 → Release 빌드 아카이브.

## D. 백엔드 운영화 (H2b 산출물 — [ADR-0001](adr/0001-backend-proxy-hosting.md))
- **[AI/사람]** 프록시 모니터링(`wrangler tail`/알림) 체계 + 일일 한도(10) **출시 후 로그 보며 조정** 계획.
- ✅ 완료: ① Console 월 spend 하드캡 / 서버 키 시크릿 주입 / 키 회전 = 분기 1회.

## E. 데이터
- ✅ 번들 DB 650 최종.
- (선택) 기존 200개 품질 재생성 — ROADMAP Next `[Data]`. `db-expand` API 키 재발급 의존(또는 claude.ai 수동).

## F. QA 게이트
- **[사람/AI]** `e2e-checklist.md` **전체 통과** — Release 빌드로 새로 1회 도는 것. 통과/실패 **판정은 ROADMAP에 기록**(이 문서는 게이트만 가리킴).

## 참조
- 상태 정본: `ROADMAP.md` → `[Ops] 출시 준비`
- [ADR-0001 백엔드 프록시 호스팅](adr/0001-backend-proxy-hosting.md) · `e2e-checklist.md`
- `DevEtym/DevEtym/Utils/AppConfig.swift` · `site/privacy-policy.md` · 백엔드 repo `devetym-proxy`(비공개)
