<p align="center">
  <img src="Resources/icon.png" alt="Maurice" width="128" height="128">
</p>

<h1 align="center">Maurice</h1>

<p align="center">
  <a href="https://github.com/MaximeChaillou/Maurice/releases"><img src="https://img.shields.io/github/v/release/MaximeChaillou/Maurice?include_prereleases&style=flat-square&color=orange" alt="Release"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2026+-blue?style=flat-square&logo=apple" alt="Platform">
  <img src="https://img.shields.io/badge/swift-6+-FA7343?style=flat-square&logo=swift&logoColor=white" alt="Swift">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/MaximeChaillou/Maurice?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/AI-Claude%20Code-blueviolet?style=flat-square" alt="Claude Code">
</p>

<p align="center">
Maurice is a macOS app that transcribes your meetings in real time and organizes them by meeting and by person.<br>
It includes a memory system, semantic search, and Markdown editing to build a personal knowledge base from your conversations.<br>
Integrated with Claude Code, it automates workflows like summarization and analysis directly from your transcripts.
</p>

---

## 📦 Installation

### Via Homebrew (recommended)

```bash
brew tap MaximeChaillou/maurice https://github.com/MaximeChaillou/Maurice
brew install --cask maurice
```

### Manual download

Download the latest version from the [Releases](https://github.com/MaximeChaillou/Maurice/releases) page.

### 🔓 Bypass Gatekeeper

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

## ✨ Features

- 🎙️ **Real-time transcription** — Live speech-to-text powered by on-device Speech Recognition
- ✍️ **Markdown editing** — Write and edit notes alongside your transcripts
- 👥 **Organization by meeting & person** — Keep track of 1-1s, assessments, and objectives
- 🧠 **Memory system** — Build a persistent knowledge base from your conversations
- 🔍 **Semantic search** — Find anything across all your meetings, people, and notes
- 🤖 **Claude Code integration** — Automate summarization, analysis, and more
- 💎 **Liquid Glass interface** — Native macOS 26 design with translucent materials

## 📄 License

[MIT](LICENSE)
