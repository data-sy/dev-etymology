# Probe Analysis — v2 라운드 직교성 측정 결과

> `closing × selfcheck × alias_strict` 2³=8 cell × 15 keyword fully crossed factorial 측정 결과.
> Claude.ai 대화로 돌아가 `handoff-v2.md` 작성 시 이 문서를 첨부할 것.

## 메타

- **Run ID**: `2026-05-15_2250`
- **Model**: `claude-sonnet-4-6`
- **Thinking budget**: 2000
- **총 호출**: 120 (8 cell × 15 keyword)
- **데이터 경로**: `Scripts/prompt-probe/results/2026-05-15_2250/`
  - `manifest.json`, `prompts_used.json`
  - `metrics/summary.csv`, `metrics/per_response.csv`
  - `raw/{cell}__{keyword}.json` × 120

## Keyword 구성

- **in_shot (4)**: `mutex`, `jpa`, `daemon`, `bug` — few-shot 예시와 동일/유사. 학습된 톤 재현 검증용
- **out_of_shot (6)**: `idempotent`, `cookie`, `semaphore`, `request`, `boolean`, `null` — few-shot에 없는 어휘. 일반화 검증용
- **branch_check (5)**: `apple`, `lunch` (비개발어), `mutext`, `redus`, `semafore` (오타) — 분기 정확도용

---

## 📊 1. 각 변경의 메인 이펙트 (baseline 대비)

| 측정값 | baseline | closing | selfcheck | alias_strict |
|---|---|---|---|---|
| oos_naming 평균 | 293.7 | **347.0** ↑ | 280.2 ↓ | 272.0 ↓ |
| oos_naming 최대 | 311 | **427** ↑↑ | 353 | 300 ↓ |
| oos_under_270 | 1/6 | 0/5 | 3/6 ↑ | 3/5 ↑ |
| aliases_qualifier | 2/10 | 2/9 | 3/10 ↑ | **1/9** ↓ ✓ |
| branch_correct | 15/15 | 14/15 | 15/15 | 14/15 |
| latency_avg | 8017ms | 7454 | **12783** | 6763 |
| thinking 활용 (chars) | 97 | 133 | **764** ↑↑ | 89 |

### 해석

- **closing 단독 = 역효과.** 의도는 "결론 멘트 금지·새 정보로 마무리"였는데, 모델이 "새 정보"를 **추가**해서 길이를 늘림 (293 → 347, max 427까지 튐). 의도가 빗나감.
- **selfcheck = 길이 제어 성공.** thinking이 ~8배(97 → 764) 활성화돼서 자기검수 동작. 다만 **레이턴시 1.6배** (8s → 13s).
- **alias_strict = 타깃 정확히 명중.** qualifier 2/10 → 1/9. 부작용으로 보이는 길이 단축은 보너스. 단, 별도 회귀 있음 (§3 참조).

---

## 📐 2. 3원 상호작용 — 직교성 판정

`closing__selfcheck` 결과만 따로 놓고 보면 **충격적**:

| 측정값 | 값 |
|---|---|
| oos_naming 평균 | **247.0** (전체 최저) |
| oos_naming 최대 | 262 |
| oos_under_270 | **6/6 (퍼펙트)** |
| branch_correct | 15/15 |
| latency_avg | 13658ms |
| thinking 활용 | 928 |

**합 예측 vs 실측 (oos_naming 평균):**

```
baseline           293.7
+ closing 효과     +53.3   (단독 측정에서 +53.3 bloat)
+ selfcheck 효과   -13.5   (단독 측정에서 -13.5 reduce)
─────────────────────────
예측합            333.5
실측              247.0
─────────────────────────
시너지            -86.5    ← 비직교, 강한 부의 상호작용
```

**해석:** closing 단독은 길이를 뻥튀기하는데, **selfcheck가 같이 켜지면 그 뻥튀기를 자기검수 단계에서 잘라낸다.** closing의 "결론 멘트 금지" 룰이 selfcheck의 "마지막 문장 점검" 단계와 만나서 비로소 동작. 이 둘은 **세트로만 의미 있음.**

전체 8 cell 비교:

| cell | oos_naming_avg | oos_under_270 | branch |
|---|---|---|---|
| baseline | 293.7 | 1/6 | 15/15 |
| closing | 347.0 | 0/5 | 14/15 |
| selfcheck | 280.2 | 3/6 | 15/15 |
| alias_strict | 272.0 | 3/5 | 14/15 |
| **closing + selfcheck** | **247.0** | **6/6** | **15/15** |
| closing + alias_strict | 329.8 | 0/5 | 14/15 |
| selfcheck + alias_strict | 280.4 | 2/5 | 14/15 |
| 3개 모두 | 267.0 | 3/5 | 14/15 |

---

## ⚠️ 3. `null` 키워드 분기 오류 — alias_strict 부작용

`alias_strict` 켜진 4개 셀 모두 `null`을 `not_dev_term`으로 오분류. baseline·selfcheck·closing__selfcheck는 정답.

| cell | null 분기 | thinking 요약 |
|---|---|---|
| baseline | ✅ term_entry | *"The user input is 'null'. This is a development term."* |
| closing | ❌ not_dev_term | "null/empty message" |
| selfcheck | ✅ term_entry | *"... a development term used in programming..."* |
| alias_strict | ❌ not_dev_term | "null/empty message" |
| closing__selfcheck | ✅ term_entry | *"... Wait — 'null' could actually be a development term!"* (selfcheck 자기검수가 구해냄) |
| closing__alias_strict | ❌ not_dev_term | "null/empty message" |
| selfcheck__alias_strict | ❌ not_dev_term | "null/empty input. Not a development term." |
| closing__selfcheck__alias_strict | ❌ not_dev_term | "input is null/empty" |

### 진단

모델이 입력 문자열 `null`을 **"빈 메시지(empty input)"로 파싱**하는 ambiguity가 있음.

**selfcheck의 3단계 절차**:
1. 입력이 세 분기 중 어디인지 판단
2. 개발 용어인 경우 etymology · namingReason 초안
3. namingReason의 마지막 문장이 새 정보를 담는지 점검

→ Step 1에서 "비개발어"로 잘못 잡으면 Step 2~3로 안 넘어감. **selfcheck는 길이 검수용이지 분기 재검토용이 아님.**

`closing__selfcheck`만 우연히 분기 재검토를 한 이유는 명확하지 않음. closing의 "결론 멘트 금지" 룰이 모델의 thinking을 한 번 더 둘러보게 했을 수 있음(약한 가설).

**원인 가설:** alias_strict가 시스템 프롬프트를 길게 만들면서 모델의 priors가 살짝 이동, "empty input" 해석 쪽으로 기울게 함. n=1이라 단정은 못 함.

### 영향 평가

- `null`은 매우 흔한 검색어 (Tony Hoare "billion-dollar mistake"로 유명).
- 1 keyword / 15 측정 keyword 중 하나지만 실제 사용자 검색 빈도는 훨씬 높을 것으로 추정.
- **prod 출시 시 사용자에게 직접 보이는 결함** — 무시 불가.

---

## 💰 4. 비용·레이턴시

| 셀 그룹 | latency_avg | output_tokens (호출당) | thinking_chars |
|---|---|---|---|
| baseline | 8.0s | ~500~600 | ~100 |
| selfcheck on (4 cells) | 12~14s | ~1000~2000 | 700~930 |
| selfcheck off (4 cells) | 6.8~8.0s | ~500~700 | ~90~130 |

- **selfcheck 셀: thinking 700~900 chars 사용** (2000 limit의 35~45%, 여유 있음)
- **호출당 비용: baseline 대비 ~2~3배 증가** (output_tokens 기준)
- **레이턴시: 8s → 13s** (사용자 체감 +5초)
- **Prompt cache**: 첫 호출 cache_create, 나머지 14건 cache_read — 기대대로 동작

---

## 🎯 5. 권고 (handoff-v2.md 기초)

### 채택 후보

| 항목 | 판정 | 근거 |
|---|---|---|
| **closing + selfcheck (세트로)** | ✅ ADOPT | 6/6 perfect length, 15/15 branch, 강한 시너지. **이번 라운드 메인 변경.** |
| **alias_strict 단독 채택** | ⚠️ CONDITIONAL | qualifier 개선(2/10 → 1/9)은 진짜인데 `null` 분기 회귀가 심각. **null 보호 룰 추가하면 함께 채택, 아니면 보류.** |
| **closing 단독** | ❌ REJECT | 단독으로 쓰면 길이 폭증 (avg 347, max 427) |
| **null 보호 룰 (신규)** | 📌 후보 | 예: `"입력 문자열이 'null', 'undefined', 'void' 같은 값 부재 키워드면 빈 입력으로 해석하지 말고 해당 개발 용어로 처리"`. [도구 선택] 섹션 끝 또는 few-shot에 추가 |

### 묶음 권장안

- **묶음 A (보수적)**: closing + selfcheck만. cache 1회 무효화. 길이 문제 해결, 분기 안정. alias_strict는 다음 라운드(v3)로 미룸.
- **묶음 B (공격적)**: closing + selfcheck + alias_strict + null 보호 룰. cache 1회 무효화에 4가지 변경 묶음. qualifier 개선까지 한 번에. 단 null 보호 룰의 실효성은 따로 검증 안 됨(n=0).

---

## ❓ Claude.ai 전문가와 마저 토론할 항목

1. **묶음 A vs B 선택** — alias_strict의 qualifier 이득과 null 회귀 위험을 어떻게 저울질할 것인가. null 보호 룰을 어디에 어떤 정확한 문구로 넣어야 효과적인가.
2. **null 보호 룰의 작성 위치** — [도구 선택] 섹션 끝 vs few-shot 추가 vs selfcheck step 1 보강. 캐시·길이·priming 측면에서 트레이드오프 비교 필요.
3. **closing 텍스트 미세 조정** — closing 단독이 길이를 늘렸다는 사실은 selfcheck와 세트로 두는 이상 문제 없지만, closing 자체 표현을 더 강하게 "줄여라"로 바꿀 여지가 있는지 (예: "마지막 문장이 새 정보가 없으면 생략" → "마지막 문장이 새 정보가 없으면 **반드시** 생략. namingReason 길이가 250자를 넘으면 마지막 문장을 다시 검토").
4. **selfcheck step 1 보강** — 분기 재검토를 명시적으로 추가할지 (예: "Step 1에서 비개발어로 판단했더라도, 해당 문자열이 프로그래밍 키워드일 가능성을 한 번 더 검토"). 단, 현 selfcheck의 길이 제어 기능을 침범하지 않도록 배치 신중.
5. **레이턴시 트레이드오프 — production 수용 가능 여부.** 첫 검색 13s는 사전 앱 UX 기준으로 허용 범위인가, 아니면 thinking budget을 2000 → 1000으로 줄여 조율할지.

---

## 부록: 첨부할 데이터

Claude.ai 대화에 이 문서와 함께 첨부 권장:

- 이 문서 (`docs/ai-quality/probe-analysis-v2.md`) — 임베드된 요약·해석
- `Scripts/prompt-probe/results/2026-05-15_2250/metrics/summary.csv` — 8 cell 집계
- `Scripts/prompt-probe/results/2026-05-15_2250/metrics/per_response.csv` — 120 호출 raw 메트릭
- (선택) `Scripts/prompt-probe/results/2026-05-15_2250/raw/{baseline,closing__selfcheck,selfcheck__alias_strict}__null.json` — null 분기 thinking 비교용
- (선택) `Scripts/prompt-probe/prompts/components.py` — 각 변경의 정확한 텍스트
