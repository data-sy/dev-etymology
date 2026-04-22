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
- Anthropic API key from [console.anthropic.com](https://console.anthropic.com)

**Steps**
1. Copy `DevEtym/Config.sample.xcconfig` to `DevEtym/Config.xcconfig`
2. Fill in `CLAUDE_API_KEY` with your Anthropic key
3. Open `DevEtym/DevEtym.xcodeproj` in Xcode
4. Pick a simulator or device running iOS 18+
5. `⌘R`

`Config.xcconfig` is gitignored so the key never reaches the repo.

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
docs/                 # privacy policy, wireframes, icon design history
```

## Documentation

- [spec.md](spec.md) — implementation specification (models, services, views, tests)
- [CLAUDE.md](CLAUDE.md) — coding conventions, architecture rules, dependency policy
- [AGENTS.md](AGENTS.md) — multi-agent development workflow (services / data / ui / settings / ai)
- [docs/privacy-policy.md](docs/privacy-policy.md) — data collection policy (Firebase Analytics, opt-in)
- [docs/wireframe-v2.html](docs/wireframe-v2.html) — UI wireframe reference
- [docs/icon/](docs/icon/) — app icon design iterations

## License

[MIT License](LICENSE) — covers the source code and the curated `terms.json` content.

Third-party fonts (DM Sans, DM Mono, DM Serif Display) are distributed under the [SIL Open Font License](https://openfontlicense.org/).
