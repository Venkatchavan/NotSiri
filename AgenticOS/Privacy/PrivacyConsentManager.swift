// Privacy/PrivacyConsentManager.swift – AgentOS
// Per-domain cloud routing consent + GDPR export

import Foundation
import Observation
import SwiftData

@Observable
final class PrivacyConsentManager {

    static let shared = PrivacyConsentManager()

    // Per-domain consent
    private(set) var domainConsents: [AgentDomain: DomainConsent] = [:]

    // Live routing indicator (shown in UI)
    private(set) var lastRouting: [AgentDomain: ProviderTier] = [:]

    private init() {
        loadConsents()
    }

    // MARK: - Consent Model

    struct DomainConsent: Codable {
        var domain: AgentDomain
        var cloudEnabled: Bool
        var allowedProviders: Set<ProviderTier>
        var lastUpdated: Date

        init(domain: AgentDomain, cloudEnabled: Bool, allowedProviders: Set<ProviderTier> = []) {
            self.domain           = domain
            self.cloudEnabled     = cloudEnabled
            self.allowedProviders = allowedProviders
            self.lastUpdated      = Date()
        }
    }

    // MARK: - Public API

    func isCloudAllowed(for domain: AgentDomain) -> Bool {
        domainConsents[domain]?.cloudEnabled ?? defaultCloudEnabled(for: domain)
    }

    func updateConsent(domain: AgentDomain, cloudEnabled: Bool, providers: Set<ProviderTier> = [.claude, .gemini]) {
        domainConsents[domain] = DomainConsent(
            domain: domain,
            cloudEnabled: cloudEnabled,
            allowedProviders: cloudEnabled ? providers : []
        )
        // Propagate to router
        var policy = LanguageModelRouter.shared.policies[domain] ?? DomainRoutingPolicy(domain: domain, cloudEnabled: cloudEnabled)
        policy.cloudEnabled = cloudEnabled
        LanguageModelRouter.shared.updatePolicy(policy)
        saveConsents()
    }

    func recordRouting(domain: AgentDomain, provider: ProviderTier) {
        lastRouting[domain] = provider
    }

    // MARK: - GDPR Export

    func exportHypergraphAsJSON(context: ModelContext) async throws -> URL {
        let tasks     = (try? context.fetch(FetchDescriptor<AgentTask>())) ?? []
        let projects  = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        let emails    = (try? context.fetch(FetchDescriptor<AgentEmail>())) ?? []
        let files     = (try? context.fetch(FetchDescriptor<AgentFile>())) ?? []
        let notes     = (try? context.fetch(FetchDescriptor<AgentNote>())) ?? []
        let people    = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        let meetings  = (try? context.fetch(FetchDescriptor<Meeting>())) ?? []
        let deadlines = (try? context.fetch(FetchDescriptor<Deadline>())) ?? []

        let export: [String: Any] = [
            "exported_at": ISO8601DateFormatter().string(from: .now),
            "version":     "1.0",
            "tasks":       tasks.map    { exportTask($0) },
            "projects":    projects.map { exportProject($0) },
            "emails":      emails.map   { exportEmail($0) },
            "files":       files.map    { exportFile($0) },
            "notes":       notes.map    { exportNote($0) },
            "people":      people.map   { exportPerson($0) },
            "meetings":    meetings.map { exportMeeting($0) },
            "deadlines":   deadlines.map{ exportDeadline($0) }
        ]

        let data = try JSONSerialization.data(withJSONObject: export, options: .prettyPrinted)
        let url  = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentOS-Export-\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: url)
        return url
    }

    // MARK: - Data Deletion

    func deleteAllData(context: ModelContext) throws {
        try context.delete(model: AgentTask.self)
        try context.delete(model: Project.self)
        try context.delete(model: AgentEmail.self)
        try context.delete(model: AgentFile.self)
        try context.delete(model: AgentNote.self)
        try context.delete(model: Person.self)
        try context.delete(model: Meeting.self)
        try context.delete(model: Deadline.self)
        // Clear keychain
        KeychainHelper.delete(key: "agentos.claude.apikey")
        KeychainHelper.delete(key: "agentos.gemini.apikey")
        for service in MCPService.allCases {
            KeychainHelper.delete(key: "agentos.mcp.\(service.rawValue).token")
        }
    }

    // MARK: - Persistence

    private func loadConsents() {
        guard let data = UserDefaults.standard.data(forKey: "agentos.domain.consents"),
              let saved = try? JSONDecoder().decode([AgentDomain: DomainConsent].self, from: data) else {
            // Privacy-safe defaults
            domainConsents = Dictionary(uniqueKeysWithValues: AgentDomain.allCases.map {
                ($0, DomainConsent(domain: $0, cloudEnabled: defaultCloudEnabled(for: $0)))
            })
            return
        }
        domainConsents = saved
    }

    private func saveConsents() {
        let data = try? JSONEncoder().encode(domainConsents)
        UserDefaults.standard.set(data, forKey: "agentos.domain.consents")
    }

    private func defaultCloudEnabled(for domain: AgentDomain) -> Bool {
        domain != .mail && domain != .files  // Mail and Files are always local
    }

    // MARK: - Export Helpers

    private func exportTask(_ t: AgentTask) -> [String: Any] {
        ["id": t.id.uuidString, "title": t.title, "completed": t.isCompleted,
         "priority": t.priority.label, "created": t.createdAt.ISO8601Format()]
    }
    private func exportProject(_ p: Project) -> [String: Any] {
        ["id": p.id.uuidString, "name": p.name, "status": p.status.rawValue]
    }
    private func exportEmail(_ e: AgentEmail) -> [String: Any] {
        ["id": e.id.uuidString, "subject": e.subject, "from": e.sender?.name ?? "",
         "received": e.receivedAt.ISO8601Format(), "replied": e.isReplied]
    }
    private func exportFile(_ f: AgentFile) -> [String: Any] {
        ["id": f.id.uuidString, "name": f.displayName, "tags": f.tags]
    }
    private func exportNote(_ n: AgentNote) -> [String: Any] {
        ["id": n.id.uuidString, "title": n.title, "source": n.source.rawValue,
         "tags": n.tags, "created": n.createdAt.ISO8601Format()]
    }
    private func exportPerson(_ p: Person) -> [String: Any] {
        ["id": p.id.uuidString, "name": p.name, "email": p.email]
    }
    private func exportMeeting(_ m: Meeting) -> [String: Any] {
        ["id": m.id.uuidString, "title": m.title, "start": m.startDate.ISO8601Format(),
         "participants": m.participants.map(\.name)]
    }
    private func exportDeadline(_ d: Deadline) -> [String: Any] {
        ["id": d.id.uuidString, "dueDate": d.dueDate.ISO8601Format(), "completed": d.isCompleted]
    }
}
