// Models/Deadline.swift – AgentOS
// Hypergraph node: deadline with multi-threshold alerts

import Foundation
import SwiftData

@Model
final class Deadline {
    var id: UUID
    var dueDate: Date
    /// Days-before thresholds that trigger proactive alerts (default: 7, 3, 1)
    var alertThresholdDays: [Int]
    var isCompleted: Bool
    var createdAt: Date

    // Relationship
    var task: AgentTask?

    /// Days remaining until deadline (negative = overdue)
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: .now, to: dueDate).day ?? 0
    }

    var isOverdue: Bool { daysRemaining < 0 && !isCompleted }

    var urgencyLevel: UrgencyLevel {
        if isCompleted { return .done }
        switch daysRemaining {
        case ..<0:  return .overdue
        case 0...1: return .critical
        case 2...3: return .high
        case 4...7: return .medium
        default:    return .low
        }
    }

    enum UrgencyLevel: String, Codable {
        case done, overdue, critical, high, medium, low
    }

    init(dueDate: Date, alertThresholdDays: [Int] = [7, 3, 1]) {
        self.id                  = UUID()
        self.dueDate             = dueDate
        self.alertThresholdDays  = alertThresholdDays
        self.isCompleted         = false
        self.createdAt           = Date()
    }
}
