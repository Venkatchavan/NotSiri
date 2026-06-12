// Models/Person.swift – AgentOS
// Hypergraph node: represents any human contact across all domains

import Foundation
import SwiftData

@Model
final class Person {
    var id: UUID
    var name: String
    var email: String
    var phone: String?
    var organization: String?
    /// Stable identifier from CNContactStore for sync
    var contactIdentifier: String?
    var createdAt: Date
    var updatedAt: Date

    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \AgentEmail.sender)
    var sentEmails: [AgentEmail] = []

    @Relationship(deleteRule: .nullify, inverse: \Meeting.participants)
    var meetings: [Meeting] = []

    init(
        name: String,
        email: String,
        phone: String? = nil,
        organization: String? = nil,
        contactIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.phone = phone
        self.organization = organization
        self.contactIdentifier = contactIdentifier
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
