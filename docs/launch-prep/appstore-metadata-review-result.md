# App Store 메타데이터 리뷰 결과 (라운드테이블 산출물)

> [`appstore-metadata-review-prompt.md`](appstore-metadata-review-prompt.md)를 실행한 결과 — 초안([`appstore-metadata-draft.md`](appstore-metadata-draft.md))을 코드·정책 물증으로 압박 테스트하고 열린 결정을 권고로 닫은 리포트.
> 수정 반영본은 [`appstore-metadata-draft-reviewed.md`](appstore-metadata-draft-reviewed.md). **상태/최종 입력 기록은 추후 `ROADMAP.md` `[Ops] 출시 준비` B** (이 리포트에는 기록하지 않음).

---

## 검증한 물증 (추측 아님 — 파일 인용)

| 확인 항목 | 결과 | 근거 |
|---|---|---|
| 검색어 원문 전송 여부 | **전송함.** `search`·`search_error` 이벤트가 `keyword` 파라미터로 검색어 원문을 Firebase에 전송 | `AnalyticsService.swift:24,32` |
| 동의 게이트(opt-in) | **opt-in 맞음.** `consentGiven` false면 즉시 return, 기본값 `defaults.bool` → false | `AnalyticsService.swift:17–18,23,31` |
| 지원 이메일 정합성 | **일치.** `oddmuffinstudio@gmail.com` (코드·방침·초안 동일) | `AppConfig.swift:9` · `privacy-policy.md:76` · draft line 72 |
| 번들 용어 수 "650" | **사실.** terms.json `keyword` 항목 650개 | `Resources/terms.json` (grep -c) |
| 개인정보방침 URL | **일치·존재.** `https://data-sy.github.io/dev-etymology/privacy-policy/` | `AppConfig.swift:privacyPolicyURL` · `site/privacy-policy.md` permalink |
| 지원 URL 페이지 내용 | **연락처 없음 (gap).** index에 개인정보방침·repo 링크뿐, "도움받는 법" 없음 | `site/index.md` |

> 참고(메타데이터 무관 doc-drift): `docs/specs/spec.md`가 아직 `Constants.reportEmail`을 가리키나 실제 코드는 `AppConfig.supportEmail` 사용(`SettingsView.swift:230`, `DetailView.swift:349`). 출시 차단 아님.

---

## 라운드 1 — 페르소나별 적대 검토

- **[프라이버시]** 검색어 원문 전송 코드 확정. 초안의 "검색 기록 유형 추가 필수" 판단은 옳음. **그러나 초안 라벨 본표(line 94)에는 식별자/사용데이터만 있고 검색 기록이 빠져 있음**(line 98에서 "추가 필수"라 적고 본표 미반영). 이 상태로 입력하면 라벨↔실제 불일치(가이드 5.1.1).
- **[심사]** ① "임의 입력→AI 응답"의 1.2(UGC) 리젝 가능성: 타인 노출 UGC가 아니라 정통 사유는 약하나, 생성형 AI에 "부적절 출력 차단 + 신고 경로"를 요구해온 전례 있음. 신고 경로 존재(`DetailView.swift:349`), 비개발어 거부(`NOT_DEV_TERM`)가 사실상 필터. **하드 블로커 아님, 완화 근거를 일관 서술**. ② "무제한 웹 접근"=아니오 (임의 URL 브라우저 없음) — 초안 정확. ③ 연령등급 4+ 와 방침 §6("만 14세 미만 대상 아님")은 모순 아님(콘텐츠 등급 vs 타깃팅). 단 **Kids Category 등록 금지**(데이터 수집과 충돌).
- **[ASO]** 키워드 A 68자/B 65자 → 100자 중 30자+ 낭비(순손해). 키워드 A의 `리액트,자바,파이썬`은 어원사전이 깊게 안 다루는 스택어 → 검색의도 미스매치(전환율↓). 의도어(B의 `기술면접,비전공,오픈소스`)가 전환 유리.
- **[사용자]** 스크린샷 1컷 "왜 버그일까? 어원부터" 후크 합격. 부제 A(차별점형)는 "무슨 앱인지"는 즉시 전달하나 "면접" 같은 상황 트리거 약함 → 부제 B가 공감 트리거 강함.
- **[출시]** 지원 URL 함정: `site/index.md`에 연락 수단 없음 → 빈 페이지 취급 위험. 개인정보방침 URL은 코드·permalink 일치 확인.

---

## 출력

### 1) 출시 차단(Blocker)

| # | 무엇이 | 왜 | 근거 | 수정안 |
|---|---|---|---|---|
| **B1** | 개인정보 라벨 본표에 **검색 기록(Search History)** 누락 | 코드가 검색어 원문 전송 → 라벨에 없으면 라벨↔실제 불일치 | `AnalyticsService.swift:24,32` / draft line 94 vs 98 | line 94 데이터 유형에 **"검색 기록(Search History) → 분석, 사용자 비연결"** 추가 |
| **B2** | 지원 URL 페이지에 **연락 수단 없음** | Apple은 기능하는 지원 URL 요구(빈 페이지 금지) | `site/index.md` | index.md에 "문의: oddmuffinstudio@gmail.com" 지원 섹션 추가 |

### 2) 열린 결정 권고표

| 결정 항목 | 권고 | 한 줄 근거 | 남은 [사람 확인] |
|---|---|---|---|
| 이름 | **A `개발 어원 사전`** | 브랜드·정확매칭, 부제로 키워드 보강 | 노출 데이터 보고 추후 B 전환 |
| 부제 | **B `면접 준비 코딩 용어, 오프라인 즉답`** | 이름 A가 키워드 흡수 적음 → 의도어(면접)+기능(오프라인)로 전환↑ | A(차별점)와 최종 택1 |
| 키워드 | **B 기반 + 100자까지 충전** | 의도어 집중이 전환 유리, 낭비 글자 제거 | 이름/부제 확정 후 중복 제외하고 채움 |
| 카테고리 | **교육 / 참고** | 학습·면접 의도 도달 | — |
| 개인정보 라벨 | 수집:예 / 식별자(기기ID)+사용데이터(제품상호작용)+**검색기록** / 분석 / 비연결 / 추적 아니오 | 코드 일치 | App Store Connect 입력 |
| 연령등급 | **4+**, 무제한 웹접근 **아니오** | 브라우저 없음, 콘텐츠 클린 | **Kids Category 등록 금지** |
| 지원 URL | GitHub Pages index (B2 수정 후) | 실제 도달 가능해야 | Pages 배포 라이브 확인 |

### 3) 초안 수정 지시 (→ `appstore-metadata-draft-reviewed.md`에 반영)

- **line 94**: 데이터 유형에 검색 기록(Search History) 행 추가.
- **line 86**: "Kids Category 등록 금지(데이터 수집과 충돌)" 한 줄 추가.
- **부제/조합(line 26·131)**: 권장 조합에 **이름 A + 부제 B(전환형)** 병기.
- **지원 URL 섹션(line 114)·체크리스트**: B2(지원 페이지 연락처 부재) 경고 추가.

### 4) Go / No-Go

**조건부 No-Go → B1·B2 닫으면 Go.**
나머지(이름/부제/키워드/카테고리/등급)는 권고로 닫혔고 사람의 최종 택1·입력만 남음. 출시 차단은 **B1(라벨)·B2(지원URL)** 둘뿐, 둘 다 즉시 처리 가능.
