# 핸드오프 H2b — 백엔드 프록시 구현 + 온디바이스 키 제거

작성 세션: 오케스트레이션 세션 2026-06-21. 실행: 별도 세션(백엔드 repo + 앱 변경).
**선행: H2a로 플랫폼이 확정돼야 시작.** 정본 상태는 `ROADMAP.md` Next "[Ops/Security] API 키 ... 백엔드 프록시".

## 문제 / 목적 (출시 하드 게이트)

앱이 `Info.plist`의 `CLAUDE_API_KEY`를 읽어 `api.anthropic.com`에 **직접** 호출 → 출시 빌드
디컴파일로 키 탈취·비용 폭증 위험. 키를 앱에서 제거하고 **얇은 백엔드 프록시**로 전환한다.

## 3층 방어 (전부 구현)

1. **① Console 월 spend 하드캡 — 즉시·호스팅 무관.** Anthropic Console에서 워크스페이스/키별 월 상한 설정 + 정기 키 회전. 다른 게 다 뚫려도 최후 안전선. **H2b 시작과 무관하게 오늘 켤 수 있음 — 사용자에게 먼저 안내.**
2. **② 온디바이스 키 제거.** 키는 프록시 서버 시크릿에만. 앱은 프록시만 호출(키 미보유).
3. **③ 기기당 일일 호출 한도 — 서버에서 강제.** 클라 카운터는 디컴파일 우회됨 → 서버 저장소(KV 등)에서만 진짜 한도. **시작값 5~10회**(H2a 확정값), 출시 후 실제 로그 보며 조정. AI 호출은 번들 DB(650) 미스일 때만 발생 → 너무 낮으면 신규 사용자가 탐색 중 조기 차단되니 5~10에서 시작.

## 실행 세션이 풀어야 할 것 (구현 설계는 실행 세션 전문가가 — 미리 답 박지 말 것)

플랫폼별 구체 구현(KV 스키마·TTL·동시성·시크릿 주입)은 실행 세션이 H2a 비교문서와 플랫폼 문서를 보고 설계. 단 아래 골격·제약은 충족:

**백엔드(별도 repo — 앱 repo에 넣지 말 것)**
- 엔드포인트: 앱 요청 받아 Claude API로 프록시(키는 서버 시크릿). 현재 앱이 보내는 요청 형태와 호환(아래 "현재 앱 호출 형태" 참조).
- 기기 식별: 앱이 보내는 익명 기기ID 헤더로 ③ 일일 카운터(저장소 키=기기ID, TTL=하루). 인증 서버는 과함 — 가벼운 기기당 rate limit이 목표.
- 한도 초과 시 명확한 상태코드/바디 → 앱이 사용자에게 "오늘 한도 초과" 안내로 분기.
- 비밀: API 키를 코드/repo에 하드코딩 금지(서버 시크릿).

**앱(이 repo)**
- `DevEtym/DevEtym/Services/ClaudeAPIService.swift`:
  - 현재 `endpoint = https://api.anthropic.com/v1/messages`, `x-api-key`에 `Bundle.main...CLAUDE_API_KEY` 주입(`apiKeyProvider`). → **프록시 baseURL로 교체, 앱에서 키·`x-api-key` 제거**.
  - 익명 기기ID 헤더 1개 추가(기존 Firebase/익명 식별자 재사용 가능).
  - `TermServiceProtocol`·`ViewModel`·MVVM 경계·`@MainActor` 무변경(서비스 내부만 교체).
- `Info.plist`의 `CLAUDE_API_KEY` 제거 + 빌드 설정/문서에서 키 주입 흔적 정리.
- 한도 초과 응답을 `ClaudeAPIError`에 분기 추가(현재 `.invalidAPIKey` 등 존재) → 사용자 메시지/Analytics 연결.
- 테스트: `ClaudeAPIServiceTests`·Mock 갱신(프록시 URL·기기ID 헤더·한도초과 분기).

### 현재 앱 호출 형태 (출발점)
- `ClaudeAPIService.swift`: `POST https://api.anthropic.com/v1/messages`, 헤더 `x-api-key`(키), `anthropic-version: 2023-06-01`. body는 tool_choice 사용(주석: extended thinking과 tool_choice any 공존 불가).
- 키 출처: `apiKeyProvider` 기본값이 `Bundle.main.object(forInfoDictionaryKey: "CLAUDE_API_KEY")`.
- 모델 ID 상수: `Constants.swift`.

## 제약
- 백엔드 repo는 분리. 앱엔 키가 어떤 형태로도 남지 않아야 함(빌드 산출물 포함).
- Force unwrap 금지·에러 do-catch 등 `CLAUDE.md` 규칙 동일 적용(앱 측).
- 한도 시작값/플랫폼은 H2a 확정값을 따름. 임의 변경 금지.

## 완료 조건
- ① 콘솔 하드캡 설정됨(사용자 확인) + 키 회전 정책 합의.
- ② 앱 빌드에 API 키 부재(디컴파일/`strings`로 키 안 나옴) + 프록시 경유 정상 검색.
- ③ 동일 기기 N회 초과 시 서버가 차단, 앱이 안내로 분기. 카운터 일 단위 리셋.
- 백엔드 repo 배포됨 + 시크릿으로 키 보관. 앱 테스트 갱신·통과.

## 참조
- 결정 문서: `h2a-backend-proxy-tradeoffs.md`
- `DevEtym/DevEtym/Services/ClaudeAPIService.swift`, `ClaudeAPIError.swift`, `Constants.swift`
- ROADMAP Next "[Ops/Security] API 키 온디바이스 제거 → 백엔드 프록시"
