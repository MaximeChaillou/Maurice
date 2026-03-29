# Maurice

Maurice is a macOS audio transcription app with Markdown editing.

## General
- Never add unrequested UI changes (shadows, animations, styling). Only change what was explicitly asked for. Respect user's editorial deletions - never reintroduce content the user removed.

## Architecture

- **Clean Architecture**: Domain → Presentation → Data
- **SwiftUI + AppKit**: NSViewRepresentable for Markdown rendering (NSTextView)
- **Swift Concurrency**: async/await in ViewModels and UseCases

## Structure

```
Sources/
├── App/              # Entry point (MauriceApp)
├── Presentation/     # SwiftUI Views, ViewModels
├── Domain/           # Entities, protocols, use cases
└── Data/             # File storage, speech recognition
```

## Code Quality

- **Background threads**: Always move file I/O, JSON encode/decode, directory scanning, and any heavy computation off the main thread. Use `Task.detached { }` for fire-and-forget work (e.g. saves), and `Task { await Task.detached { ... }.value }` to load data then update the UI. Never block the main thread.
- **SwiftLint**: Always fix all SwiftLint warnings and errors. Run `swiftlint lint --config .swiftlint.yml` and resolve every issue before considering a task complete. Never use `// swiftlint:disable` to bypass a rule — always fix the underlying code (extract structs, refactor parameters, etc.). When a SwiftLint warning appears (including during a build or test), fix it **immediately** before continuing — never ignore or defer a warning.
- **Code reuse**: Maximize reuse of existing code. Before creating a new function, check if a similar implementation already exists in the project. Extract common patterns into shared methods/extensions rather than duplicating code.
- **Shared components**: Use components from `DateNavigationComponents.swift` (`DateNavigationHeader`, `DateEntryContentView`, `TranscriptToggleButton`, `SkillActionsMenu`, `EntryActionsMenu`, `GlassIconButton`, `.deletionAlert()`, `.entryDeleteAlert()`). For markdown file editing, reuse `FolderFileEditorView` / `FolderFileDetailView` with `FolderFile(url:)` — do not recreate load/save logic.
- **Tests**: When a new feature is implemented, always add corresponding tests in `Tests/` (file + `project.pbxproj` entries). When a method/protocol is removed, always check and update corresponding tests and mocks in `Tests/`. Tests must **never** touch user files — use only temporary directories (`NSTemporaryDirectory`) and mocks. No reading/writing to `~/Documents/Maurice/` or `AppTheme.persistenceURL` from tests.
- **Code removal**: When code is removed (method, file, property), trace all references in the project AND tests. Also remove `project.pbxproj` entries for deleted files.
- **No hardcoded absolute paths**: Never hardcode absolute paths in the code (e.g. `/Users/maxime/...`). Always resolve paths dynamically via `NSHomeDirectory()`, `AppSettings.rootDirectory`, `Bundle.main`, `FileManager.default.urls(for:in:)`, or lookup mechanisms (`which`, multiple candidates). The app must work on any machine.

## UI

- **Liquid Glass**: Use Liquid Glass style (macOS 26) for all UI elements — `.glassEffect()`, buttons, bars, panels. Prefer translucent materials and rounded shapes.

## Conventions

- UI language: French — all user-facing strings must go through the `Localizable.xcstrings` file (`Resources/Localizable.xcstrings`). Use English as the source key in code (SwiftUI `Text("Key")` or `String(localized: "Key")` for non-SwiftUI contexts like `NSOpenPanel`) and provide the French translation in the xcstrings file. Never hardcode French strings directly in Swift code.
- Data storage: configurable via `AppSettings.rootDirectory` (default `~/Documents/Maurice/`)
- Markdown theme: `.maurice/theme.json` (hidden folder in root)
- Search index: `.maurice/search_index.json`
- Memory files: `Memory/`
- Tasks: `Tasks.md` (capitalized)
- AI configuration: `CLAUDE.md` + `.claude/commands/`

## Build & Run

- Use **XcodeBuildMCP** for build, run, and test. Do not use `xcodebuild` in shell.
- Call `session_show_defaults` before the first build of the session.
- This is a **macOS** app: use XcodeBuildMCP's macOS workflow (not iOS simulator).
- After each completed task, **relaunch the app** to verify.
- After a large task, run **SwiftLint** (`swiftlint lint --config .swiftlint.yml`) and fix all issues.
- Do **not** run tests automatically after each task — only run tests when the user requests a release or explicitly asks to run tests.

## Xcode Project

- **Never** install Ruby dependencies (xcodeproj gem, etc.) to modify the project.
- To add files to the Xcode project, edit `project.pbxproj` directly (PBXFileReference, PBXGroup, PBXBuildFile, PBXSourcesBuildPhase).

## Release & Distribution

- Distribution via **Homebrew Cask** (`Casks/maurice.rb`) and **GitHub Releases**.
- Automatic updates via **Sparkle** (EdDSA key in Keychain, public key in `Info.plist`).
- Update feed: `appcast.xml` at the repo root.
- **Before any release**, run tests (`test_macos`) and verify they all pass at 100%. If a test fails, **block the release** and fix the issue first.
- **Release steps** (strict order — no commits allowed after the GitHub release):
  1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` (4 occurrences each)
  2. Commit and push the version bump
  3. Run `./Scripts/create_release.sh <version>` — this builds, zips, signs with Sparkle, updates `appcast.xml`, and creates the GitHub Release with tag
  4. Get the zip SHA256 (`shasum -a 256 /tmp/Maurice-<version>.zip`) and update `Casks/maurice.rb` (version + sha256)
  5. Commit and push `appcast.xml` + `Casks/maurice.rb`
  6. Update the GitHub release notes with the changelog via `gh release edit`
- **TODO**: steps 4-6 should be integrated into `create_release.sh` so the final commit happens before `gh release create`, avoiding post-tag commits.
- The app is **not Apple signed** — users must unblock Gatekeeper (`xattr -cr`).
- Each release must include an **English changelog** listing changes since the last version (new features, fixes, improvements).
- The version number must be updated in `MARKETING_VERSION` in `project.pbxproj` (4 occurrences) for each release. This value controls the version displayed in the app. Never hardcode the version in `Info.plist` — use `$(MARKETING_VERSION)`.
- **Build number**: `CURRENT_PROJECT_VERSION` in `project.pbxproj` (4 occurrences) must be incremented for each release. It is a simple integer (1, 2, 3...). Sparkle compares this build number (via `sparkle:version` in the appcast) to detect updates. `sparkle:shortVersionString` contains the human-readable name (e.g. `1.0.0-beta.4`). Never use pre-release versions (with `-beta`, `-rc`, etc.) in `sparkle:version` — always an integer.


## Settings & Configuration

- All paths derive from `AppSettings.rootDirectory` — never hardcode absolute paths.
- `AppSettings` centralizes UserDefaults (`rootDirectory`, `onboardingCompleted`, `transcriptionLanguage`).
- When `rootDirectory` changes, call `reloadAfterDirectoryChange()` in `MauriceApp` to update all ViewModels.
- Transcription language is read from `AppSettings.transcriptionLanguage` (not hardcoded in `SpeechRecognitionService`).
