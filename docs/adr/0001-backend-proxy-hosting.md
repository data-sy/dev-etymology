# ADR 0001: 백엔드 프록시 호스팅 — Cloudflare Workers + KV

## Status
Accepted (2026-06-22) · Implemented 2026-06-23 (PR [#26](https://github.com/data-sy/dev-etymology/pull/26))

## Context
출시 빌드는 디컴파일로 `Info.plist`의 Claude API 키를 추출당할 수 있어 키 탈취·비용 폭증 위험이 있다.
키를 앱에서 제거하고 **얇은 프록시**(앱 → 자체 서버 → Claude API, 키는 서버에만)로 전환해야 한다.

3층 방어를 분리해 보면:
- ① Console 월 spend 하드캡 — 코드 무관, 어떤 선택이든 즉시 병행(손실 상한).
- ② 온디바이스 키 제거 — 프록시 필요(어디든).
- ③ 기기당 일일 호출 한도 — **서버 저장소(KV 등)에서만** 강제 가능(클라 카운터는 디컴파일 우회). → **이 카운터 저장소가 플랫폼 선택의 결정 축.**

트래픽 현실: AI 호출은 번들 DB(650개) **미스일 때만** 발생 → 매우 낮음. 실질 제약은 요청 수가 아니라 **카운터 write 한도**.

## Decision
**Cloudflare Workers + KV.** 기기당 일일 한도 시작값 = **10회**(출시 후 로그 보며 조정). ① Console 월 하드캡은 병행.

## Consequences

### Positive
- 무료 티어 내 **$0**, 콜드스타트 **0ms**.
- **KV 내장** → ③ 카운터를 단일 시스템에서 종결(외부 저장소 결선 불필요). `wrangler deploy` 단일 파일 운영.
- 비상업 약관 제약 없음 → 수익화에도 안전. iOS 변경 최소(baseURL/헤더 교체 + 기기ID 헤더 1개).

### Negative
- **KV write 1K/day가 진짜 천장** — 매 AI-미스마다 1 write. 폭증 시 여기가 먼저 막힘.
- **KV 최종 일관성**(수초 전파) → 일일 한도가 약간 느슨하게 샐 수 있음(버스트 시). 비용 방어엔 무해, 엄격 원자 카운팅엔 부적합.
- CF KV 바인딩 고유 → 락인 낮~중.

### Neutral
- 백엔드는 앱 repo와 분리된 별도 repo(`devetym-proxy`, 비공개).

## Alternatives Considered
1. **Vercel/Netlify Functions + Upstash** — 2순위. 외부 KV(Upstash)·시크릿 2곳 결선 필요. ⚠️ **Vercel Hobby는 비상업 한정**(유료앱/IAP면 약관 위반 소지) → Netlify가 이 용도엔 무난.
2. **VPS (Fly.io/Render 직접)** — 비권고. 이 트래픽엔 과잉(OS·패치·모니터 운영 부담). 장점은 락인 최소뿐.
3. **프록시 없음(하드캡·키회전만)** — 비권고. ② 미해결로 키가 온디바이스 잔존 → 탈취 자체를 못 막고 ③ 불가. 단 ①은 어떤 선택이든 병행.

## 권고가 뒤집히는 트리거
- AI-미스 폭증(하루 수천+ write) 또는 **엄격 원자 카운팅** 필요 → 무료 KV 병목 → 카운터만 **Durable Objects**(유료)로 이전.
- 이미 Vercel/Netlify에 인프라 쏠림 → 2순위 역전 고려.
- 벤더 락인 회피 최우선 → VPS($5~7/월 + 운영 부담 지불).

## References
- 구현: PR [#26](https://github.com/data-sy/dev-etymology/pull/26) · 백엔드 repo: `devetym-proxy`(비공개)
- 출처: Cloudflare [Workers Limits](https://developers.cloudflare.com/workers/platform/limits/) · [KV Limits](https://developers.cloudflare.com/kv/platform/limits/) · [Durable Objects Limits](https://developers.cloudflare.com/durable-objects/platform/limits/) · [Vercel Fair Use](https://vercel.com/docs/limits/fair-use-guidelines) · [Upstash Pricing](https://upstash.com/docs/redis/overall/pricing)
