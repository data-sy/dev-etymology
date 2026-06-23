# 핸드오프 H2b — 백엔드 프록시 구현 + 온디바이스 키 제거

작성 세션: 오케스트레이션 세션 2026-06-21. 실행: 별도 세션(백엔드 repo + 앱 변경).
정본 상태는 `ROADMAP.md` Next "[Ops/Security] API 키 ... 백엔드 프록시".

## ✅ 착수 준비 상태 (2026-06-22 갱신)

- **선행 게이트 H2a 통과** — 플랫폼 **확정: Cloudflare Workers + KV**, 기기당 **일일 한도 시작값 10회**(출시 후 로그 보며 조정). 근거: `h2a-backend-proxy-tradeoffs.md` 확정란.
- **새 세션 권장.** 도메인이 iOS UI와 완전히 달라(Worker JS + KV + wrangler 배포) 깨끗한 컨텍스트가 유리.
- **인터랙티브 선행 셋업 (사람/계정 필요 — 코딩 전에 확인):**
  1. Cloudflare 계정 + `wrangler` CLI 설치·`wrangler login`.
  2. KV 네임스페이스 생성(③ 기기당 카운터 저장소).
  3. **서버용 Anthropic API 키 필요** — 기존 db-expand 키는 노출되어 폐기됨(ROADMAP Later "[Ops/Security] db-expand API 키 재발급" 참조). 새 키 발급 후 **Worker 시크릿**(`wrangler secret put`)으로만 주입, repo/코드에 금지.
  4. **① Console 월 spend 하드캡**은 호스팅과 무관하게 *오늘이라도* 켤 수 있는 최후 안전선 — 먼저 안내·설정 권장.

## 진행 로그 (2026-06-22)

**완료 — 앱 측 (이 repo)**
- `ClaudeAPIService` 프록시 전환: 엔드포인트 → `Constants.proxyBaseURL`, `x-api-key`/`apiKeyProvider`/키 가드 제거,
  `X-Device-Id` 헤더 추가, HTTP 429 → `ClaudeAPIError.dailyLimitExceeded` 분기.
- `DeviceIdentifier`(신규, `Utils/`): 익명 UUID를 UserDefaults에 1회 생성·보관. **분석 동의와 분리**
  (Firebase App Instance ID는 동의 게이트되어 nil이면 검색이 막히므로 전용 ID 사용). `nonisolated`.
- `ClaudeAPIError`: 죽은 `.invalidAPIKey` 제거, `.dailyLimitExceeded` 추가. `AnalyticsErrorType`도 동일 치환
  (`invalid_api_key`→`daily_limit_exceeded`). `TermService`·`DetailViewModel`(사용자 메시지) 분기 갱신.
- 키 제거: `Info.plist`의 `CLAUDE_API_KEY` 삭제, `Config.xcconfig`(로컬·키 폐기)·`Config.sample.xcconfig` 비움.
  문서 정리: `README.md`, `docs/specs/spec.md`.
- 테스트/Mock 갱신: 키 테스트 → 429·기기ID 헤더·키부재 테스트로 교체. **테스트 통과(TEST SUCCEEDED).**
- **완료조건 ② 바이너리 검증**: 클린 빌드 산출물 `DevEtym.app`에 `sk-ant` 0건, `CLAUDE_API_KEY` 0건.

**완료 — 백엔드 (별도 repo `~/devetym-proxy`, 앱 repo와 분리)**
- Cloudflare Workers 스캐폴드: `src/index.js`(얇은 패스스루 + KV 기기당 일일 한도, 시크릿 키 주입),
  `wrangler.toml`, `package.json`, README, `.gitignore`, `.dev.vars.example`. wrangler 4.86 설치, `--dry-run` 통과, 초기 커밋.
- 계약: 앱이 기존 Anthropic body를 그대로 POST + `X-Device-Id` 헤더 → Worker가 키 주입·전달, 성공(2xx)만 카운트,
  초과 시 429 `{error:"daily_limit_exceeded",limit:10}`. KV 키 `rl:<deviceId>:<UTC날짜>`, TTL 48h.

**완료 — 배포 + 서버 검증 (2026-06-23)**
- ① Console: 워크스페이스 분리 + 각 월 spend 하드캡 설정 완료(사용자).
- 서버용 새 Anthropic 키 발급 → `wrangler secret put`으로 주입(디스크 백업 없음).
- Cloudflare 가입·`wrangler login` 완료. KV 네임스페이스 생성(id `513c44bf6df942eab2262397bbec04de`) → `wrangler.toml` 반영.
  workers.dev 서브도메인 `data-sy-2` 등록. `workers_dev=true`/`preview_urls=false`(표면 축소)로 배포.
- **배포 URL: `https://devetym-proxy.data-sy-2.workers.dev`** → 앱 `Constants.proxyBaseURL`에 반영.
- 서버 측 스모크 검증(curl): 기기ID 없음 → 400 / 정상 요청 → 200(키 주입 동작) / 카운터 KV 증가 확인 /
  한도(10) 도달 → 429 `daily_limit_exceeded`. 테스트 KV 키는 정리함.

**완료 — 앱 런타임 경유 검증 (2026-06-23, 시뮬 iPhone 17 / iOS 26.5)**
- 번들 미스 용어 `quine` 검색 → 프록시 경유 AI 결과(어원·작명이유) 정상 렌더, "✦ AI 생성" 배지 확인.
- 서버 측: 앱의 익명 기기 UUID(`92C10618-…`) 카운터가 KV에 `1`로 증가 — 앱 실호출이 ③ 한도에 집계됨 확인.
- → 완료조건 ②(프록시 경유 정상 검색) + ③(서버 카운트) 앱 런타임까지 닫힘.

**키 회전 정책 (합의 2026-06-23)**: 프록시 서버 Anthropic 키는 **분기 1회 정기 회전**, 노출 의심 시 즉시 회전.
회전은 `wrangler secret put ANTHROPIC_API_KEY`로 무중단 교체 후 Console에서 구 키 폐기.

**429 앱-UI 검증 (2026-06-23)**: 앱 기기 카운터를 KV에서 10으로 세팅 → 새 용어 검색 → 실제 앱에 "오늘 AI 검색 한도를
모두 사용했어요" 오류 안내 렌더 확인(Anthropic 호출 0). 테스트 후 카운터 삭제로 원복.
**일 리셋**: 날짜키(`:<UTC날짜>`) + 48h TTL 설계로 보장 — 실제 자정 롤오버는 미관측(관측엔 날짜 경과 필요).

**남은 것**
- (별건) `Scripts/prompt-probe` 키 소스 정리 → 완료(README에서 Config.xcconfig awk 추출 제거).
- 실기기 최종 확인은 선택(시뮬에서 이미 통과).

**별건(범위 밖, 플래그)**: `Scripts/prompt-probe/README.md`가 `Config.xcconfig`에서 키를 awk로 읽는데 이제 빈 값.
이 dev 툴은 env var 등 별도 키 소스로 정리 필요(앱 키 제거와 무관한 독립 유틸).

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
