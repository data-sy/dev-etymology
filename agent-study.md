# 멀티 에이전트 스터디 — Claude Code 병렬 작업 이해하기

## 1. "에이전트"의 두 가지 의미

멀티 에이전트라는 말은 맥락에 따라 전혀 다른 두 가지를 가리킨다. 이 둘을 혼동하면 설계가 엉킨다.

### (A) 여러 Claude Code 세션 = 멀티 에이전트
- 터미널(또는 tmux pane, iTerm 탭)을 여러 개 띄우고, 각 터미널에서 독립적으로 `claude` 세션을 실행
- 각 세션은 **완전히 독립된 context**를 가짐 — 서로의 대화를 모름
- 실제 팀의 개발자 여러 명이 각자 자기 브랜치에서 작업하는 것과 동일한 구조
- 실제 "parallel development"에 해당하는 본격적인 멀티 에이전트

### (B) 한 세션 안의 서브에이전트
- 한 Claude Code 세션이 `Agent` 툴로 **자식 에이전트**를 띄우는 방식
- 같은 cwd 안에서 병렬 조사나 독립된 파일 수정 같은 용도
- 부모 세션의 샌드박스 경계를 상속 — 부모의 cwd 밖 경로에는 접근 못 함
- "이 방대한 코드베이스 어디에 X가 있는지 찾아봐" 같은 research 분담에 적합

### 흔한 오해
> "한 폴더 안에서 에이전트 A, B, C가 서로 다른 브랜치에서 동시 작업할 수 있지 않나?"

불가능하다. 한 물리 폴더는 git 브랜치를 **하나만** 체크아웃할 수 있다. 브랜치별로 병렬 작업하려면 **물리 폴더를 분리**해야 한다. 그게 git worktree의 존재 이유다.

## 2. git worktree 이해하기

### 핵심 개념
> **worktree는 "별도 프로젝트"가 아니다. 같은 git 저장소의 다른 체크아웃일 뿐이다.**

- 한 repo의 `.git/`을 공유하면서, 서로 다른 브랜치를 동시에 물리적으로 펼쳐놓는 git 기능
- 각 worktree 폴더의 `.git`은 디렉토리가 아닌 **파일** — 안에 `gitdir: /경로/원본repo/.git/worktrees/<이름>` 형태로 원본 저장소 위치가 적혀 있음
- 모든 커밋, 브랜치, 오브젝트는 **원본 repo의 `.git/` 한 곳에만 저장**됨
- 그래서 어느 worktree에서 커밋하든, 원본 repo에서 `git branch -a` 하면 전부 보인다

### 기본 명령
```bash
# worktree 생성 (새 브랜치와 함께)
git worktree add ../devetym-services -b feat/services

# worktree 목록
git worktree list

# worktree 제거 (작업 완료 후)
git worktree remove ../devetym-services
```

### 배치 관례
- **Sibling(형제 폴더):** `../devetym-services` — 가장 표준적. repo 자체가 오염되지 않음
- **Repo 내부 숨김:** `.worktrees/services` — 한 폴더 안에 모든 것 두고 싶을 때. `.gitignore`에 추가 필수
- **홈 디렉토리:** `~/worktrees/<repo>-<branch>` — 프로젝트 여러 개 관리 시 흔한 방식

### GUI와 실제의 차이
Finder/Explorer에서는 `dev-etymology`, `devetym-services`, `devetym-ui`, `devetym-db`가 **별도 폴더처럼** 보인다. 하지만 git 관점에서는 **하나의 저장소**다. 이 이중성이 worktree의 핵심이고 처음엔 혼란스럽다.

## 3. Claude Code의 `--worktree` 플래그

Claude Code에는 worktree를 자동 생성하고 진입하는 전용 플래그가 있다.

```bash
claude --worktree feature-auth     # .claude/worktrees/feature-auth/ 자동 생성 + 해당 위치에서 세션 시작
claude --worktree                  # 이름 자동 생성 (예: bright-running-fox)
```

- 생성 위치는 `.claude/worktrees/<이름>/`
- 브랜치 이름은 `worktree-<이름>` 자동 부여
- 세션 종료 시 변경 없으면 자동 정리
- `.gitignore`에 `.claude/worktrees/` 추가 권장

수동 worktree 생성과 차이점은 "편의"뿐이다. 브랜치 명명 규칙이나 폴더 배치를 직접 관리하고 싶으면 `git worktree add`를 쓴다.

## 4. 표준 멀티 에이전트 워크플로우

목표: 3개 브랜치(`feat/services`, `feat/ui`, `feat/bundle-db`)에서 병렬 개발 후 main으로 머지

### Step 1 — worktree 준비
```bash
cd dev-etymology
git worktree add ../devetym-services -b feat/services
git worktree add ../devetym-ui       -b feat/ui
git worktree add ../devetym-db       -b feat/bundle-db
```

### Step 2 — tmux로 병렬 세션 구성
```bash
tmux new -s devetym                              # 새 tmux 세션 시작
# pane 3개로 수직 분할 (Ctrl+b %, Ctrl+b " 등)

# pane 1
cd /Users/owner/devetym-services && claude

# pane 2
cd /Users/owner/devetym-ui && claude

# pane 3
cd /Users/owner/devetym-db && claude
```

### Step 3 — 각 Claude에게 역할 부여
각 pane의 Claude에게 다음과 같은 지시:
```
이 저장소의 spec.md, CLAUDE.md, AGENTS.md를 읽어.
너는 AGENTS.md의 "Agent A — 서비스 레이어" 담당이다.
해당 섹션의 작업 지시대로 Phase 2 Services를 구현하고,
논리 단위로 Conventional Commits 커밋해라.
push/PR은 하지 마. 커밋까지만.
```
Agent A/B/C 부분만 바꿔서 각 pane에 붙여넣는다.

### Step 4 — 머지
각 Claude가 커밋 완료하면 원본 repo(`dev-etymology`)에서:
```bash
git checkout main
git merge feat/services
git merge feat/bundle-db
git merge feat/ui
```
또는 각 브랜치를 push해서 PR로 리뷰 후 머지.

### Step 5 — 정리
```bash
git worktree remove ../devetym-services
git worktree remove ../devetym-ui
git worktree remove ../devetym-db
git branch -d feat/services feat/ui feat/bundle-db
```
최종적으로 `dev-etymology` 하나만 남고, main에 모든 작업이 통합된 상태가 된다.

## 5. 메인 세션(허브)과 실행 세션 분리

대규모 작업 시 유용한 패턴:
- **메인 세션(허브):** 원본 repo(`dev-etymology`)에서 실행. 설계 상담, 아키텍처 결정, 머지 전략, 충돌 해결 판단 담당. 컨텍스트 길게 유지
- **실행 세션(일꾼):** 각 worktree에서 tmux pane별로 실행. 지시받은 구현만 수행, 끝나면 종료해도 됨

실제 팀 구조(PM/아키텍트 + 개발자들)와 유사하다. 컨텍스트 오염을 막고, 설계/구현 책임을 분리할 수 있다.

## 6. 삽질 포인트 — 서브에이전트로 병렬 브랜치 작업 시도했을 때

부모 세션에서 서브에이전트 3개를 띄워 각자 다른 worktree에서 작업하도록 지시했더니:

```
All operations on /Users/owner/devetym-services/ are denied.
Permission denied.
```

**원인:** 서브에이전트는 부모의 cwd(`/Users/owner/dev-etymology`) 밖 경로에 접근 못 한다. 샌드박스 안전장치다.

**교훈:**
- 병렬 브랜치 개발 = **멀티 Claude 세션** (tmux)이 맞다
- 서브에이전트는 같은 cwd 안의 독립된 작업에만 써야 한다
- AGENTS.md가 가정하는 "여러 에이전트가 각 worktree에서 병렬 작업"은 **사람이 직접 띄운 여러 Claude 세션**을 전제한 것

## 7. 최종 이해한 흐름

> 현재 저장소는 `dev-etymology`. 이 안에 Swift 프로젝트 `DevEtym`이 있고, `AGENTS.md` / `CLAUDE.md` / `spec.md` / `README.md`가 같은 층위에 있다.
>
> Phase 2를 병렬로 진행하기 위해 tmux를 사용한다. 각 Claude 세션의 작업 위치는 `dev-etymology`와 **같은 층위(sibling)**인 `devetym-services`, `devetym-ui`, `devetym-db` 폴더들이다.
>
> GUI상으로는 네 개의 별도 폴더처럼 보이지만, **실제로는 하나의 git 저장소(`dev-etymology`)를 공유**하는 worktree들이다. 각 worktree에서 수행한 커밋은 `dev-etymology/.git/`에 기록된다.
>
> 세 에이전트의 작업이 끝나면 `dev-etymology`에서 main 브랜치로 세 feat 브랜치를 머지한다. 머지 완료 후 worktree들을 제거하면, 최종적으로 **`dev-etymology`만 남고 main에 모든 작업이 통합**된 상태가 된다.

이 흐름이 멀티 에이전트 병렬 개발의 기본형이다.
