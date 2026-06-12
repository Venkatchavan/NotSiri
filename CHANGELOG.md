# Changelog

All notable changes to AgentOS (NotSiri) will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Version numbers follow [Semantic Versioning](https://semver.org/).

---

## [1.0.0] – 2026-06-12

### Added
- **SwiftData Hypergraph** with 8 linked entities: `Person`, `Project`, `AgentTask`, `AgentEmail`, `AgentFile`, `AgentNote`, `Deadline`, `Meeting`
- **6 Domain Agents** + **CoordinatorAgent** (parallel dispatch via `withThrowingTaskGroup`)
  - CalendarAgent (EventKit), MailAgent (local-only), TasksAgent (Reminders), FilesAgent (local-only), NotesAgent (Obsidian/Notion/local), ResearchAgent (Gemini real-time)
- **Foundation Models routing layer** (`LanguageModelRouter`) — on-device → Claude Sonnet → Gemini with per-domain user consent
- **Continuous ambient voice listening** with "Hey AgentOS" wake phrase (on-device `SFSpeechRecognizer`)
- **7 App Intents** registered with Siri: Query, AddTask, ScheduleMeeting, DraftEmail, FindFiles, CrossDomainQuery, ProactiveDigest
- **Proactive Intelligence Engine** — `NSBackgroundActivityScheduler` every 30 min; overdue tasks, 48h email alerts, 7/3/1-day deadline warnings
- **MCP Bridge** — GitHub (issues/PRs), Obsidian (vault), Notion (databases) via OAuth 2.0 PKCE
- **Three-column macOS dashboard** — Timeline | Active Focus | Agent Chat with Liquid Glass aesthetic
- **MenuBarExtra** quick panel for ambient access
- **Per-domain privacy consent UI** with live routing indicator
- **GDPR export** — one-button full hypergraph JSON archive
- **watchOS companion app** — 5 quick-action tiles + Multipeer Connectivity Mac proxy
- **CloudKit schema** for lightweight metadata sync (content never synced)
- **PrivacyInfo.xcprivacy** full API usage declaration

### Security
- API keys and OAuth tokens stored exclusively in macOS Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)
- Mail body content and file content hard-coded as local-only (routing override impossible)
- SwiftData store encrypted via Data Protection `.completeUntilFirstUnlock`
- `.gitignore` blocks secrets, provisioning profiles, and derived data

---

## [Unreleased]

### Planned
- iOS 27 companion widget surface
- On-device Reminders two-way sync
- GitHub Copilot context bridging via MCP
- Certificate pinning for production API calls
- Face ID / Touch ID lock for sensitive query history
