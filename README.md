# Maurice

A macOS audio transcription app with Markdown editing.

## Installation

### Via Homebrew (recommended)

```bash
brew tap MaximeChaillou/maurice https://github.com/MaximeChaillou/Maurice
brew install --cask maurice
```

### Manual download

Download the latest version from the [Releases](https://github.com/MaximeChaillou/Maurice/releases) page.

### Bypass Gatekeeper

Maurice is not signed with an Apple Developer account. macOS will block the app on first launch.

**Method 1 — Right-click:**
1. Open Finder and go to `/Applications`
2. **Right-click** (or Ctrl+click) on Maurice.app
3. Click **Open**
4. Confirm in the dialog

**Method 2 — Terminal:**

```bash
xattr -cr /Applications/Maurice.app
```

This removes the quarantine attributes. You only need to run it once.

## Features

- Real-time audio transcription (Speech Recognition)
- Markdown editing
- Organization by meeting and by person
- Memory and task system
- Claude Code integration
- Liquid Glass interface (macOS 26)

## License

MIT
