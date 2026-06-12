// Views/PrivacyConsentView.swift – AgentOS
// Per-domain cloud routing consent + live routing indicator + GDPR export

import SwiftUI
import SwiftData

struct PrivacyConsentView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var consent = PrivacyConsentManager.shared
    @State private var showDeleteConfirm = false
    @State private var exportURL: URL?
    @State private var isExporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Privacy & Routing", systemImage: "lock.shield.fill")
                    .font(.title2.bold())
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Routing consent per domain
                    Section {
                        ForEach(AgentDomain.allCases) { domain in
                            DomainConsentRow(domain: domain, consent: consent)
                        }
                    } header: {
                        SectionHeader(title: "Domain Cloud Routing", subtitle: "Mail and Files are always local regardless of this setting")
                    }

                    Divider()

                    // Provider indicators
                    Section {
                        ForEach(AgentDomain.allCases) { domain in
                            HStack {
                                Image(systemName: domain.systemImage)
                                    .foregroundStyle(Color(hex: domain.accentColorHex) ?? .accentColor)
                                Text(domain.rawValue).font(.callout)
                                Spacer()
                                let provider = consent.lastRouting[domain] ?? .onDevice
                                ProviderPill(provider: provider)
                            }
                        }
                    } header: {
                        SectionHeader(title: "Last Seen Routing", subtitle: "Where each domain's last query was processed")
                    }

                    Divider()

                    // GDPR
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Export all your data as a JSON archive. Includes tasks, notes, emails, files, and contacts — no cloud tokens included.")
                                .font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Button {
                                    isExporting = true
                                    Task {
                                        exportURL = try? await consent.exportHypergraphAsJSON(context: modelContext)
                                        isExporting = false
                                    }
                                } label: {
                                    Label(isExporting ? "Exporting…" : "Export Data", systemImage: "square.and.arrow.up")
                                }
                                .disabled(isExporting)

                                Button(role: .destructive) {
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete All Data", systemImage: "trash")
                                        .foregroundStyle(.red)
                                }
                            }
                            .buttonStyle(.bordered)

                            if let url = exportURL {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    Text("Exported: \(url.lastPathComponent)")
                                        .font(.caption)
                                }
                                ShareLink(item: url, subject: Text("AgentOS Data Export")) {
                                    Label("Share Export", systemImage: "square.and.arrow.up")
                                        .font(.caption)
                                }
                            }
                        }
                    } header: {
                        SectionHeader(title: "Data & GDPR", subtitle: "Your rights under GDPR / CCPA")
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 600)
        .confirmationDialog("Delete all AgentOS data? This cannot be undone.", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) {
                try? consent.deleteAllData(context: modelContext)
            }
        }
    }
}

// MARK: - Domain Consent Row

private struct DomainConsentRow: View {
    let domain: AgentDomain
    let consent: PrivacyConsentManager

    private var isLocked: Bool { domain == .mail || domain == .files }
    private var isEnabled: Bool { consent.isCloudAllowed(for: domain) }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: domain.systemImage)
                .foregroundStyle(Color(hex: domain.accentColorHex) ?? .accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(domain.rawValue).font(.callout.bold())
                Text(isLocked ? "Always local — privacy boundary" : (isEnabled ? "Cloud-assisted synthesis allowed" : "On-device only"))
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Spacer()

            if isLocked {
                Label("Local Only", systemImage: "lock.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
            } else {
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { consent.updateConsent(domain: domain, cloudEnabled: $0) }
                ))
                .labelsHidden()
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ProviderPill: View {
    let provider: ProviderTier
    var color: Color {
        switch provider {
        case .onDevice: return .green
        case .claude:   return .purple
        case .gemini:   return .blue
        }
    }
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(provider.rawValue).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
