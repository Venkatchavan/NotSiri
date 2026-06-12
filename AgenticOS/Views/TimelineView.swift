// Views/TimelineView.swift – AgentOS
// Column 1: Universal timeline of all entities with timestamps
// "Calendar of Everything"

import SwiftUI
import SwiftData

struct TimelineView: View {

    @Binding var selectedDomain: AgentDomain?
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AgentTask.createdAt, order: .reverse) private var tasks:    [AgentTask]
    @Query(sort: \Meeting.startDate,   order: .forward)  private var meetings: [Meeting]
    @Query(sort: \AgentEmail.receivedAt, order: .reverse) private var emails: [AgentEmail]
    @Query(sort: \AgentNote.updatedAt,  order: .reverse) private var notes:   [AgentNote]

    @State private var filterDomain: AgentDomain? = nil
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Timeline")
                    .font(.title2.bold())
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // Domain filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(label: "All", systemImage: "square.grid.2x2",
                                   isActive: filterDomain == nil) { filterDomain = nil }
                        ForEach(AgentDomain.allCases) { domain in
                            FilterChip(label: domain.rawValue, systemImage: domain.systemImage,
                                       isActive: filterDomain == domain) { filterDomain = domain }
                        }
                    }
                    .padding(.horizontal, 12)
                }

                // Search
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search timeline…", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 8)

            Divider()

            // Timeline
            List(timelineItems, id: \.id) { item in
                TimelineItemRow(item: item)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Timeline Item Aggregation

    private var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []

        // Tasks
        if filterDomain == nil || filterDomain == .tasks {
            items += tasks
                .filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }
                .map { TimelineItem(id: $0.id.uuidString, domain: .tasks, title: $0.title,
                                    subtitle: $0.project?.name,
                                    date: $0.updatedAt, isCompleted: $0.isCompleted,
                                    badge: $0.priority.label) }
        }

        // Meetings
        if filterDomain == nil || filterDomain == .calendar {
            items += meetings
                .filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }
                .map { TimelineItem(id: $0.id.uuidString, domain: .calendar, title: $0.title,
                                    subtitle: "\($0.participants.count) participant(s)",
                                    date: $0.startDate, badge: $0.formattedDuration) }
        }

        // Emails
        if filterDomain == nil || filterDomain == .mail {
            items += emails
                .filter { searchText.isEmpty || $0.subject.localizedCaseInsensitiveContains(searchText) }
                .map { TimelineItem(id: $0.id.uuidString, domain: .mail, title: $0.subject,
                                    subtitle: $0.sender?.name, date: $0.receivedAt,
                                    isUnread: !$0.isRead) }
        }

        // Notes
        if filterDomain == nil || filterDomain == .notes {
            items += notes
                .filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }
                .map { TimelineItem(id: $0.id.uuidString, domain: .notes, title: $0.title,
                                    subtitle: $0.source.rawValue, date: $0.updatedAt) }
        }

        return items.sorted { $0.date > $1.date }
    }
}

// MARK: - Timeline Item Model

struct TimelineItem: Identifiable {
    let id: String
    let domain: AgentDomain
    let title: String
    let subtitle: String?
    let date: Date
    var isCompleted: Bool = false
    var isUnread: Bool    = false
    var badge: String?    = nil
}

// MARK: - Timeline Row

private struct TimelineItemRow: View {
    let item: TimelineItem

    var body: some View {
        HStack(spacing: 12) {
            // Domain indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: item.domain.accentColorHex) ?? .blue)
                .frame(width: 3)
                .frame(height: 44)

            Image(systemName: item.domain.systemImage)
                .foregroundStyle(Color(hex: item.domain.accentColorHex) ?? .blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout.weight(item.isUnread ? .bold : .regular))
                    .strikethrough(item.isCompleted)
                    .lineLimit(1)
                if let sub = item.subtitle {
                    Text(sub).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.date.relativeFormatted).font(.caption2).foregroundStyle(.tertiary)
                if let badge = item.badge {
                    Text(badge).font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear,
                            in: Capsule())
                .overlay(Capsule().stroke(isActive ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extensions

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8)  & 0xFF) / 255,
            blue:  Double( value        & 0xFF) / 255
        )
    }
}
