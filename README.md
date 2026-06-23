# DevEtym (개발 어원 사전)

An iOS dictionary app that explains the etymology and naming rationale of programming terms in Korean.

Search `mutex` and learn it comes from Latin *mutuus* (mutual) + *exclusio* (exclusion), not just that it's a lock. Search `daemon` and see how Maxwell's demon inspired the Unix background process.

## Features

- **Search** — English dev terms resolved to Korean etymology + naming rationale
- **Dual source** — bundled curated DB (500+ terms) with Claude API fallback for uncommon words
- **Bookmarks & history** — stored on-device only
- **Onboarding** with explicit AI-generated content disclosure
- **Settings** — appearance mode (system/light/dark), app info, legal notices
- **Accessibility** — Dynamic Type, VoiceOver labels, dark-mode-first design

## Tech Stack

- **UI**: SwiftUI
- **Persistence**: SwiftData (iOS 18+ required for `#Unique` / `#Index` macros)
- **AI**: Anthropic Claude API with extended thinking, tool use, and prompt caching
- **Testing**: XCTest + Swift Testing
- **Minimum iOS target**: 18.0

## Build & Run

**Prerequisites**
- Xcode 16+

**Steps**
1. Copy `DevEtym/Config.sample.xcconfig` to `DevEtym/Config.xcconfig` (빈 설정 — 키 불필요)
2. Open `DevEtym/DevEtym.xcodeproj` in Xcode
3. Pick a simulator or device running iOS 18+
4. `⌘R`

앱은 Anthropic API 키를 갖지 않는다. 모든 Claude 호출은 백엔드 프록시(`devetym-proxy`, 별도 repo)를
경유하며 키는 프록시 서버 시크릿에만 존재한다. 프록시 URL은 `Constants.proxyBaseURL` 에 있다.

## Project Structure

```
DevEtym/
├── App/              # @main entry, ContentView
├── Features/         # Search, Detail, Bookmark, History, Onboarding, Settings
├── Models/           # SwiftData @Model classes, DTOs, enums
├── Services/         # TermService (orchestrator), BundleDBService, ClaudeAPIService
├── Utils/            # Constants, EnvironmentKeys
├── Resources/        # terms.json, fonts, asset catalog
└── Tests/            # unit tests + mocks

Scripts/              # generate_db.py — batch bundle DB generator
docs/                 # internal docs — specs, design assets, ADRs, handoffs
```

## Documentation

- [docs/specs/spec.md](docs/specs/spec.md) — implementation specification (models, services, views, tests)
- [CLAUDE.md](CLAUDE.md) — coding conventions, architecture rules, dependency policy
- [site/privacy-policy.md](site/privacy-policy.md) — data collection policy (Firebase Analytics, opt-in) — published
- [docs/design/wireframe.html](docs/design/wireframe.html) — UI wireframe reference
- [docs/design/icon/](docs/design/icon/) — app icon design iterations

## License

[MIT License](LICENSE) — covers the source code and the curated `terms.json` content.

Third-party fonts (DM Sans, DM Mono, DM Serif Display) are distributed under the [SIL Open Font License](https://openfontlicense.org/).
