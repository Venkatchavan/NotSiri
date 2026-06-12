# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | ✅ Yes    |

## Reporting a Vulnerability

Please **do NOT** open a public GitHub issue for security vulnerabilities.

Instead, email: **security@[your-domain].com** (replace with your contact).

We will acknowledge within 48 hours and aim to patch within 7 days for critical issues.

## Privacy & Credential Handling

AgentOS is designed to be **credential-leak-proof by architecture**:

| Data type | Storage |
|-----------|---------|
| Claude / Gemini API keys | macOS Keychain only (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) |
| GitHub / Notion / Obsidian OAuth tokens | macOS Keychain only |
| Email body content | Never leaves device — local-only, hard-coded constraint |
| File content | Never leaves device — local-only, hard-coded constraint |
| Calendar / tasks metadata | On-device Foundation Models; optional Claude/Gemini with explicit user consent |
| CloudKit sync | Metadata only, encrypted by iCloud end-to-end encryption |

## What is Never Committed to This Repository

- API keys or tokens of any kind
- `.env` files or secrets files
- Provisioning profiles or certificates
- User data or SwiftData databases

See `.gitignore` for the full exclusion list.

## Dependency Security

All external API calls use:
- HTTPS only
- OAuth 2.0 PKCE for third-party services (GitHub, Notion)
- Certificate pinning for production builds (roadmap)

## Responsible Disclosure

We follow [Coordinated Vulnerability Disclosure](https://cheatsheetseries.owasp.org/cheatsheets/Vulnerability_Disclosure_Cheat_Sheet.html).
