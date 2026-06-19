# 핸드오프 — 독스(`docs/`) 발행 범위 정리 + 재정돈

> **사용법.** 새 세션에서 *"이 파일(`handoff-docs-cleanup.md`) 읽고 진행해줘"* 라고 하면 된다.
> 이 작업은 [번들 DB 확장 Phase 2](docs/db-expand/handoff-phase2.md)보다 **먼저** 하기로 결정됨 (발행 노출을 빨리 막고, 이후 산출물이 올바른 위치에 생기도록).

## 왜 (문제)

- `docs/`가 GitHub Pages(Jekyll, `docs/_config.yml`에 `exclude` **없음**)로 **통째 발행**됨 → 내부 문서가 전부 공개됨.
- Pages source: `main` `/docs` (ROADMAP "Ops" 항목). **실제 활성화 여부는 세션이 확인할 것** — 아직 TODO(미활성)일 수 있음. `gh api repos/data-sy/dev-etymology/pages` 등으로 확인 후 긴급도 판단.

## 현재 `docs/` 내용 (분류 초안 — 세션이 각 파일 열어 검증·확정)

| 파일/폴더 | 추정 분류 | 비고 |
|---|---|---|
| `index.md` | **공개** | 사이트 랜딩 |
| `privacy-policy.md` | **공개(필수)** | 앱/법적 — 반드시 접근 가능해야 함 |
| `_config.yml` | 설정 | Jekyll 설정 (이동 대상 아님) |
| `spec.md` | 내부 | ※ 루트에도 `spec.md` 존재 — 중복/역할 확인 |
| `adr/` | 내부 | 의사결정 기록 |
| `ai-quality/` | 내부 | 프롬프트 라운드·핸드오프 |
| `db-expand/` | 내부 | spec·rounds·runbook·**handoff-phase2.md** |
| `design-followup.md` | 내부 | `../ROADMAP.md` 참조 |
| `typography-review.md` | 내부 | |
| `wireframe-v2.html` | 내부 | |

→ 위는 추정. **공개 적합성은 세션이 직접 판단**하고, 먼저 한 줄 분류표로 사용자 승인받을 것.

## 목표

1. 발행되는 건 공개 의도 페이지(`index.md`·`privacy-policy.md`)만.
2. 김에 `docs/` 전체를 훑어 **재정돈** — stale·중복 문서 정리, 폴더 구조 일관화.

## 접근 옵션 (세션이 택1, 트레이드오프 명시 후 사용자 승인)

1. **내부 문서를 `docs/` 밖으로 이동** (예: 루트 `internal/` 또는 `docs-internal/`). Pages는 `docs/` 루트를 그대로 발행하므로 "빼는" 게 누출 위험이 가장 낮음. 대신 링크 경로 다수 수정.
2. **`docs/`에 두고 `_config.yml`에 `exclude:` 명시.** 파일은 그대로, 설정만. 이동 비용 0이나 exclude 누락 시 재노출 위험.
3. **하이브리드** — 공개용만 `docs/` 최소 유지, 나머지 이동.

권장 판단 기준: 확실성(1: 이동) vs 이동 비용(링크 깨짐). 보통 1이 안전.

## 반드시 할 것 (이동 택할 경우)

- **이동 전**: inbound 링크 전수 grep (상대경로 포함). 이미 알려진 참조 — `docs/design-followup.md`→`../ROADMAP.md`, `db-expand/handoff-phase2.md`·`spec.md` 상호 링크, `ROADMAP.md`의 `docs/...` 링크들.
- **이동은 `git mv`** (히스토리 보존).
- **이동 후 모든 참조 경로 수정**: `ROADMAP.md`, `AGENTS.md`, `CLAUDE.md`, `README.md`, `Scripts/`, 그리고 `db-expand/handoff-phase2.md` **내부의 상대경로**(`../../ROADMAP.md` 등)도 새 위치 기준으로 갱신.

## 검증

- `docs/`에 남은 게 공개 의도 파일뿐인지 확인.
- 깨진 링크 없음 (가능하면 링크 체크).
- Pages 활성 상태면 빌드 후 내부 문서가 404인지 확인.

## 규칙 (CLAUDE.md / 사용자)

- 커밋: Conventional Commits, **scope 없이** (`docs:`/`chore:`), **Co-Authored-By 트레일러 금지**.
- 삭제·이동 전 내용 확인. 이동은 `git mv`.

## 가장 먼저 할 것

`docs/` 각 파일을 한 줄로 **공개/내부 분류표** 작성 → 사용자 승인 게이트 → 승인 후 이동. (이동은 링크 깨짐을 유발하니 분류 확정 전엔 파일을 옮기지 말 것.)

## 이 작업이 끝나면

`db-expand/handoff-phase2.md` 위치가 바뀌었을 수 있으니, 그다음 세션엔 **새 경로**로 Phase 2 핸드오프를 가리킬 것. ROADMAP "Now"의 링크도 함께 갱신.
