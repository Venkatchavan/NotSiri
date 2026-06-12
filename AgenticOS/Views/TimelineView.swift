// Views/TimelineView.swift – AgentOS
// Column 1: Universal timeline of all entities with timestamps

import SwiftUI
import SwiftData

struct TimelineView: View {

    @Binding var selectedDomain: AgentDomain?
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AgentTask.createdAt,    order: .reverse) private var tasks:    [AgentTask]
    @Query(sort: \Meeting.startDate,      order: .forward)  private var meetings: [Meeting]
    @Query(sort: \AgentEmail.receivedAt,  order: .reverse)  private var emails:   [AgentEmail]
    @Query(sort: \AgentNote.updatedAt,    order: .reverse)  private var notes:    [AgentNote]

    @State private var filterDomain: AgentDomain? = nil
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ───────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Text("Timeline")
                    .font(.title3.bold())
                    .padding(.horizontal, 14)
                    .padding(.top, 14)

                // ── Domain filter bar ─────────────────────────────────────
                // Uses a ScrollView with .fixedSize so buttons always get taps
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        DomainFilterChip(
                            label: "All",
                            icon: "square.grid.2x2.fill",
                            color: .primary,
                            isSelected: filterDomain == nil
                        ) {
                            withAnimation(.easeInOut(duration: 0.18)) { filterDomain = nil }
                        }
                        ForEach(AgentDomain.allCases) { domain in
                            DomainFilterChip(
                                label: domain.rawValue,
                                icon: domain.systemImage,
                                color: Color(hex: domain.accentColorHex) ?? .blue,
                                isSelected: filterDomain == domain
                            ) {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    filterDomain = filterDomain == domain ? nil : domain
                                }
                            }
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false) // KEY: lets HStack use natural width
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                }

                // ── Search ────────────────────────────────────────────────
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField("Search…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 6)

            Divider()

            // ── Timeline list ─────────────────────────────────────────────
            if timelineItems.isEmpty {
                emptyState
            } else {
                List(timelineItems, id: \.id) { item in
                    TimelineItemRow(item: item)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: filterDomain?.systemImage ?? "tray")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(filterDomain == nil ? "Timeline is empty" : "No \(filterDomain!.rawValue) items")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Tap ↻ in the toolbar to sync your\nCalendar, Reminders and Contacts.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Timeline Item Aggregation

    private var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []

        if filterDomain == nil || filterDomain == .tasks {
            items += tasks
                .filter { !$0.isCompleted }
                .filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }
                .map { TimelineItem(id: $0.id.uuidString, domain: .tasks, title: $0.title,
                                    subtitle: $0.project?.name,
                                    date: $0.updatedAt, isCompleted: $0.isCompleted,
                                    badge: $0.priority.label) }
        }
        if filterDomain == nil || filterDomain == .calendar {
            items += meetings
                .filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }
                .map { TimelineItem(id: $0.id.uuidString, domain: .calendar, title: $0.title,
                                    subtitle: $0.startDate.formatted(date: .abbreviated, time: .shortened),
                                    date: $0.startDate, badge: $0.formattedDuration) }
        }
        if filterDomain == nil || filterDomain == .mail {
            items += emails
                .filter { searchText.isEmpty || $0.subject.localizedCaseInsensitiveContains(searchText) }
                .map { TimelineItem(id: $0.id.uuidString, domain: .mail, title: $0.subject,
                                    subtitle: $0.sender?.name, date: $0.receivedAt,
                                    isUnread: !$0.isRead) }
        }
        if filterDomain == nil || filterDomain == .notes {
            items += notes
                .filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }
                .map { TimelineItem(id: $0.id.uuidString, domain: .notes, title: $0.title,
                                    subtitle: $0.source.rawValue, date: $0.updatedAt) }
        }

        return items.sorted { $0.date > $1.date }
    }
}

// MARK: - Domain Filter Chip
// Designed to be reliably tappable on macOS inside a horizontal ScrollView.

private struct DomainFilterChip: View {
    let label:      String
    let icon:       String
    let color:      Color
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : color.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    Capsule().fill(color.opacity(label == "All" ? 0.55 : 0.9))
                } else {
                    Capsule().fill(.quaternary)
                }
            }
            .contentShape(Capsule()) // ensures entire area is tappable
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Timeline Item Model

struct TimelineItem: Identifiable {
    let id:          String
    let domain:      AgentDomain
    let title:       String
    let subtitle:    String?
    let date:        Date
    var isCompleted: Bool    = false
    var isUnread:    Bool    = false
    var badge:       String? = nil
}

// MARK: - Timeline Row

private struct TimelineItemRow: View {
    let item: TimelineItem

    var body: some View {
        HStack(spacing: 10) {
            // Accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: item.domain.accentColorHex) ?? .blue)
                .frame(width: 3, height: 38)

            // Domain icon
            Image(systemName: item.domain.systemImage)
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: item.domain.accentColorHex) ?? .blue)
                .frame(width: 18)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout.weight(item.isUnread ? .semibold : .regular))
                    .strikethrough(item.isCompleted, color: .secondary)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .lineLimit(1)
                if let sub = item.subtitle {
                    Text(sub)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // Right side: date + badge
            VStack(alignment: .trailing, spacing: 3) {
                Text(item.date.relativeFormatted)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if let badge = item.badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.quinary, in: Capsule())
                }
                if item.isUnread {
                    Circle()
                        .fill(Color(hex: item.domain.accentColorHex) ?? .blue)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
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
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8)  & 0xFF) / 255,
            blue:  Double( value        & 0xFF) / 255
        )
    }
}
