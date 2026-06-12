# AgentOS — NotSiri

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2026%2B-blue?style=flat-square&logo=apple" />
  <img src="https://img.shields.io/badge/watchOS-27%2B-lightgrey?style=flat-square&logo=apple" />
  <img src="https://img.shields.io/badge/Xcode-26%2B-blue?style=flat-square&logo=xcode" />
  <img src="https://img.shields.io/badge/Swift-6-orange?style=flat-square&logo=swift" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" />
  <img src="https://img.shields.io/badge/privacy-local--first-success?style=flat-square&logo=shield" />
  <img src="https://img.shields.io/github/v/release/Venkatchavan/NotSiri?style=flat-square" />
  <img src="https://img.shields.io/github/actions/workflow/status/Venkatchavan/NotSiri/ci.yml?style=flat-square&label=CI" />
</p>

<p align="center">
  <strong>Unified Voice-Controlled Life Dashboard for macOS</strong><br/>
  Your personal AI chief of staff — proactive, context-aware, privacy-first.
</p>

---

## Overview

AgentOS is an ambient intelligence layer for macOS that unifies **calendar, email, tasks, research notes, files, and career context** into a single voice-controlled command surface.  
It uses Apple **Foundation Models** for on-device reasoning and optionally routes complex queries to Claude or Gemini — always respecting per-domain privacy boundaries you control.

> Say **"Hey AgentOS"** and just ask. No menus. No apps. Just answers.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Voice Pipeline                                                      │
│  "Hey AgentOS…" → SFSpeechRecognizer (on-device) → VoiceRouter      │
└───────────────────────────┬─────────────────────────────────────────┘
                            │ utterance + intent
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│  CoordinatorAgent  (Foundation Models, on-device classifier)         │
│  Classifies → dispatches to domain agents in parallel                │
└──────┬──────┬──────┬──────┬──────┬──────────────────────────────────┘
       │      │      │      │      │
  Calendar  Mail  Tasks  Files  Notes  Research
 (EventKit)(local)(Rmdr)(local)(Obsid)(Gemini)
       │      │      │      │      │      │
       └──────┴──────┴──────┴──────┴──────┘
                       │
                       ▼
             SwiftData Hypergraph
   Person ↔ Email  │  Project ↔ Task ↔ Deadline
   Meeting ↔ Person[]  │  Note  │  File
```

### Provider Routing

| Query type | Provider | User-configurable |
|-----------|----------|------------------|
| Simple factual | Apple on-device Foundation Models | — (always local) |
| Cross-domain synthesis | Claude Sonnet 4 | ✅ per domain |
| Real-time web context | Gemini | ✅ per domain |
| Mail body content | **Always local** | ❌ locked |
| File content | **Always local** | ❌ locked |

---

## Features

### 🎙 Voice
- Continuous ambient listening with **"Hey AgentOS"** wake phrase
- On-device speech recognition via `SFSpeechRecognizer` (privacy-first)
- TTS response via `AVSpeechSynthesizer`

### 🤖 Multi-Agent
| Agent | Data Source | Cloud |
|-------|-------------|-------|
| Calendar | EventKit | Optional |
| Mail | Local only | **Never** |
| Tasks | Reminders + SwiftData | Optional |
| Files | FileProvider + SwiftData | **Never** |
| Notes | Local + Obsidian + Notion | Optional |
| Research | Web | Optional (Gemini) |

### ⚡ Proactive Intelligence
- Runs every 30 min via `NSBackgroundActivityScheduler`
- Alerts: overdue tasks · unanswered emails >48h · deadlines at 7/3/1 days
- 100% on-device — no cloud calls without an explicit query

### 🔗 MCP Integrations
Configured via [`mcp-manifest.json`](mcp-manifest.json):
- **GitHub** — list/create issues and PRs (OAuth PKCE)
- **Obsidian** — vault search/read/write (Local REST API)
- **Notion** — database query/create (OAuth PKCE)

### 🍎 App Intents (Siri Shortcuts)
`Ask AgentOS` · `Morning Briefing` · `Add Task` · `Schedule Meeting` · `Draft Email` · `Find Files` · `Cross-Domain Query`

### ⌚ watchOS Companion
- 5 quick-action tiles (Next Task, Today's Meetings, Morning Digest, Urgent Emails, Overdue)
- On-watch Foundation Models for simple queries
- Complex queries proxied to Mac via **Multipeer Connectivity**

---

## Privacy

AgentOS is **local-first by design**:

| Data | Where it lives |
|------|----------------|
| All AI processing (default) | Apple Silicon on-device |
| API keys & OAuth tokens | macOS Keychain only |
| Email body | Never leaves device |
| File content | Never leaves device |
| SwiftData database | Encrypted via Data Protection `.completeUntilFirstUnlock` |
| CloudKit sync | Metadata only, iCloud end-to-end encrypted |

See [SECURITY.md](SECURITY.md) for the full security policy.

---

## Requirements

| Requirement | Minimum |
|-------------|---------|
| macOS | Golden Gate (26.0+) |
| watchOS | 27.0+ (companion) |
| Xcode | 26.0+ |
| Hardware | Apple Silicon (M-series) for on-device Foundation Models |

---

## Getting Started

### 1. Clone & Open
```bash
git clone https://github.com/Venkatchavan/NotSiri.git
cd NotSiri
open AgenticOS.xcodeproj
```

### 2. Add Files to Xcode Target
All source files live in subdirectories but need to be added to the Xcode target:
1. In Xcode, select the **AgenticOS** project in the Navigator
2. Right-click the `AgenticOS` group → **Add Files to "AgenticOS"**
3. Select all new folders: `Models/` `AI/` `Agents/` `Voice/` `Intents/` `Intelligence/` `Integrations/` `Privacy/` `Views/`
4. For the Watch app: **File → New → Target → watchOS App**, then add `AgenticOSWatch/` files

### 3. Configure API Keys *(optional — app works fully on-device without these)*
Launch the app → **⚙️ Settings** → enter keys:
- **Claude**: [console.anthropic.com](https://console.anthropic.com)
- **Gemini**: [aistudio.google.com](https://aistudio.google.com)

Keys are stored in the macOS **Keychain** — never in code or iCloud.

### 4. Connect MCP Services *(optional)*
- **GitHub / Notion**: tap 🔒 Privacy → connect via OAuth flow
- **Obsidian**: install the [Local REST API plugin](https://github.com/coddingtonbear/obsidian-local-rest-api), paste the API key in Privacy settings

### 5. Grant Permissions
On first launch, grant: Calendar · Reminders · Contacts · Microphone · Speech Recognition

---

## Project Structure

```
AgenticOS/
├── Models/               # SwiftData hypergraph (8 entities)
├── AI/                   # LanguageModelRouter + DomainAgent protocol
├── Agents/               # 6 domain agents + CoordinatorAgent
├── Voice/                # AmbientListeningManager + VoiceCommandRouter
├── Intents/              # 7 App Intents + Siri shortcuts
├── Intelligence/         # ProactiveIntelligenceEngine
├── Integrations/         # EventKit, Contacts, MCP bridge
├── Privacy/              # PrivacyConsentManager + GDPR export
├── Views/                # Three-column dashboard + MenuBarExtra
└── AgenticOSWatch/       # watchOS companion
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⇧L` | Start ambient listening |
| `⌘⇧D` | Morning briefing |

---

## Releases

See [CHANGELOG.md](CHANGELOG.md) for version history.  
Download the latest release from [GitHub Releases](https://github.com/Venkatchavan/NotSiri/releases).

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m "feat: add my feature"`
4. Push: `git push origin feature/my-feature`
5. Open a Pull Request

Please read [SECURITY.md](SECURITY.md) before contributing — especially regarding secrets.

---

## License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.

---

<p align="center">
  Built with ❤️ using Foundation Models · SwiftData · App Intents · Swift Concurrency
</p>
