# H2a — 백엔드 프록시 호스팅 옵션 트레이드오프 (결정 문서)

> 목적: 출시 빌드 디컴파일로 인한 Claude API 키 탈취/비용 폭증 위험을 막기 위해 "얇은 프록시"
> (앱 → 자체 서버 → Claude API, 키는 서버에만)로 전환. **이 문서는 확정 전 비교다.**
> 사용자가 이 문서를 보고 플랫폼을 최종 확정한 뒤 H2b(구현)를 실행한다. 권고는 §3에만 둔다.
> 작성: 오케스트레이션 세션 2026-06-21 (웹 조사 기반, 출처 §출처).

## 0. 먼저 분리: 3층 방어 ≠ 호스팅 선택

| 방어층 | 무엇 | 호스팅 의존? |
|---|---|---|
| ① Console 월 spend 하드캡 | 코드 무관, 콘솔에서 워크스페이스/키별 월 상한 → 키가 새도 손실 상한 | **무관 (지금 당장)** |
| ② 온디바이스 키 제거 | 키를 서버에만, 앱은 프록시만 호출 | 프록시 필요(어디든) |
| ③ 기기/사용자당 일일 한도 | 서버에서 강제(클라 카운터는 우회됨) | **저장소(KV) 필요 → 플랫폼 선택의 핵심 축** |

→ ①은 **오늘 바로** 켠다(어떤 옵션이든 무조건 병행). ②③이 프록시를 정당화하며, ③의 카운터 저장소 유무가 비교의 결정 축.

## 1. 트래픽 현실
- AI 호출은 **번들 DB(650개) 미스일 때만** → 매우 낮음. 비관적 상한도 하루 수백~수천 프록시 요청.
- 이 규모의 실질 제약은 "요청 수"가 아니라 **카운터 write 한도**(요청마다 카운터 증가).

## 2. 비교표

| 축 | Cloudflare Workers + KV | Vercel/Netlify Functions (+Upstash) | VPS (Fly.io/Render 직접) | 프록시 없음(하드캡·키회전만) |
|---|---|---|---|---|
| 무료 한도 | Workers 100K req/day, KV 100K read/day·**1K write/day**·1GB | Vercel 1M 호출/월 · Netlify 125K/월 · Upstash ≈10K cmd/day | 사실상 없음(Fly 체험후 유료, Render 무료는 슬립) | $0 인프라 |
| 예상 월비용 | **$0** | **$0** (Vercel Hobby 비상업 한정 ⚠️) | $5~7+/월 | $0 |
| rate-limit 저장소 | **KV 내장** | 없음 → Upstash 등 **외부 추가 필수** | Redis/SQLite 직접 | 없음(서버 카운터 불가) |
| 콜드스타트 | **없음**(~0ms) | 함수 낮음 / Render 무료는 30~50초 슬립 | always-on이면 없음(유료) | 해당없음 |
| 운영 부담 | 낮음(`wrangler deploy`, 단일파일) | 낮음+외부KV·시크릿 2곳 | **높음**(OS·패치·모니터) | 거의 없음 |
| 키 보안 | 서버만 ✅ | 서버만 ✅ | 서버만 ✅ | ❌ **키 온디바이스 잔존** |
| 기기당 한도 난이도 | **낮음**(KV get→증가→put, TTL=하루; per-key 분산) | 중(Upstash ratelimit, 단 두 시스템 결선) | 중~높(직접 TTL·동시성) | **불가** |
| iOS 변경량 | 작음(baseURL/헤더 교체 + 기기ID 헤더 1개) | 작음(동일) | 작음(동일) | 0 |
| 락인 | 낮~중(KV 바인딩 CF 고유) | 중(함수+Upstash 2곳) | **가장 낮음** | 해당없음 |

### 결정적 각주
- **⚠️ Vercel Hobby = 비상업 한정.** 유료앱/광고/IAP면 약관 위반 소지 → Pro($20/월~). Netlify·Cloudflare엔 이 제약 없음.
- **KV write 1K/day가 진짜 천장.** 매 AI-미스 요청마다 1 write → 무료 KV는 하루 ~1,000 AI-미스 검색까지. 폭증 시 여기가 먼저 막힘. 출구: 한도 도달 기기는 더 write 안 함 / 원자적 카운팅 필요하면 **Durable Objects**(유료 영역)로 카운터만 이전.
- **KV 최종일관성**(수초 전파). 일일 한도엔 무해(약간 느슨하게 새는 정도). 엄격 원자 카운팅엔 Durable Objects.
- **Upstash 무료도 일 한도(≈10K cmd/day)** + 두 번째 서비스 가입·토큰 관리 증가.

## 3. 권고
- **1순위: Cloudflare Workers + KV.** 무료 티어 내 $0, 콜드스타트 0, **KV 내장**으로 ③을 단일 시스템에서 종결. 비상업 약관 제약 없어 수익화에도 안전. 운영·앱 변경 최소. 저트래픽·캐시우선 개인 앱에 최적.
- **2순위: Vercel/Netlify Functions + Upstash.** 이미 그 생태계에 익숙하면 합리적. 단 두 시스템 결선·시크릿 2곳, **Vercel은 비상업 약관 확인 필수**(Netlify가 이 용도엔 무난).
- **비권고: VPS.** 이 트래픽엔 과잉. 장점은 락인 최소뿐.
- **비권고(단 즉시 병행): 프록시 없음.** 키가 온디바이스 잔존(②미해결)이라 탈취 자체를 못 막고 ③도 불가. 콘솔 하드캡은 "손실 상한"이지 "도난 방지"가 아님. **단 ①(월 하드캡+정기 키 회전)은 어떤 선택이든 오늘 병행.**

## 4. 권고가 뒤집히는 트리거
- **수익화 계획 생김** → Vercel Hobby 탈락, Cloudflare/Netlify 우위 확대.
- **이미 Vercel/Netlify에 인프라 쏠림** → 2순위가 역전(외부 KV 한 겹 감수).
- **AI-미스 폭증(하루 수천+ write) 또는 엄격 원자 카운팅 필요** → 무료 KV 병목 → Durable Objects로 카운터 이전.
- **벤더 락인 회피 최우선** → VPS($5~7/월+운영 부담 지불).

## 출처
- Cloudflare [Workers Limits](https://developers.cloudflare.com/workers/platform/limits/) · [KV Limits](https://developers.cloudflare.com/kv/platform/limits/) · [KV write 1/sec per key](https://developers.cloudflare.com/kv/api/write-key-value-pairs/) · [Durable Objects Limits](https://developers.cloudflare.com/durable-objects/platform/limits/)
- [Vercel Pricing/Hobby](https://vercel.com/pricing) · [Vercel Fair Use(상업)](https://vercel.com/docs/limits/fair-use-guidelines) · [Netlify Functions billing](https://docs.netlify.com/build/functions/usage-and-billing/) · [Upstash Pricing](https://upstash.com/docs/redis/overall/pricing)
- [Fly.io Pricing](https://fly.io/pricing/) · [Render free tier 2026](https://render.com/articles/platforms-with-a-real-free-tier-for-developers-in-2026)
- ① [Anthropic Workspaces/spend](https://platform.claude.com/docs/en/manage-claude/workspaces) · [Rate limits](https://platform.claude.com/docs/en/api/rate-limits)

---
**사용자 확정란:** 플랫폼 = ____________  / 기기당 일일 한도 시작값 = ____회  / 확정일 = ________
확정 후 → H2b 실행. ROADMAP Next 항목에 결정 반영.
