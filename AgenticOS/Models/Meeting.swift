// Models/Meeting.swift – AgentOS
// Hypergraph node: calendar meeting with participant graph

import Foundation
import SwiftData

@Model
final class Meeting {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var location: String?
    var notes: String
    /// Stable EventKit calendar identifier
    var eventKitIdentifier: String?
    var createdAt: Date

    // Relationships – many-to-many with Person
    var participants: [Person] = []

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }

    var formattedDuration: String {
        let mins = Int(duration / 60)
        if mins < 60 { return "\(mins)m" }
        let hrs = mins / 60
        let rem = mins % 60
        return rem > 0 ? "\(hrs)h \(rem)m" : "\(hrs)h"
    }

    var isUpcoming: Bool { startDate > .now }
    var isOngoing: Bool  { startDate <= .now && endDate >= .now }

    init(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        participants: [Person] = []
    ) {
        self.id                 = UUID()
        self.title              = title
        self.startDate          = startDate
        self.endDate            = endDate
        self.location           = location
        self.notes              = ""
        self.participants       = participants
        self.createdAt          = Date()
    }
}
