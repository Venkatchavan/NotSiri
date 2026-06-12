// Models/AgentEmail.swift – AgentOS
// Hypergraph node: email metadata ONLY – full body never stored in cloud

import Foundation
import SwiftData

@Model
final class AgentEmail {
    var id: UUID
    /// Stable Message-ID header for deduplication
    var messageID: String
    var subject: String
    /// 200-char preview – never the full body (privacy boundary)
    var bodyPreview: String
    var isRead: Bool
    var isReplied: Bool
    var receivedAt: Date
    var createdAt: Date

    // Relationships
    var sender: Person?

    init(
        messageID: String,
        subject: String,
        bodyPreview: String,
        receivedAt: Date,
        sender: Person? = nil
    ) {
        self.id          = UUID()
        self.messageID   = messageID
        self.subject     = subject
        self.bodyPreview = String(bodyPreview.prefix(200))
        self.isRead      = false
        self.isReplied   = false
        self.receivedAt  = receivedAt
        self.sender      = sender
        self.createdAt   = Date()
    }
}
