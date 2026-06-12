// Views/ActiveFocusView.swift – AgentOS
// Column 2: Domain-specific deep view for current focus area

import SwiftUI
import SwiftData

struct ActiveFocusView: View {

    let domain: AgentDomain?
    @Environment(\.modelContext) private var modelContext

    // Bare @Query avoids SwiftData generating a private parameterised init
    @Query private var allTasks: [AgentTask]
    @Query private var allMeetings: [Meeting]
    @Query private var allNotes: [AgentNote]

    @State private var coordinator = CoordinatorAgent.shared
    @State private var showingAddTask = false

    // Derived filtered/sorted views
    private var openTasks: [AgentTask] {
        allTasks.filter { !$0.isCompleted }
                .sorted { $0.createdAt > $1.createdAt }
    }
    private var meetings: [Meeting] {
        allMeetings.sorted { $0.startDate < $1.startDate }
    }
    private var notes: [AgentNote] {
        allNotes.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        Group {
            switch domain ?? .tasks {
            case .calendar:  CalendarFocusSection(meetings: meetings)
            case .mail:      MailFocusSection()
            case .tasks:     TasksFocusSection(tasks: openTasks, showAddTask: $showingAddTask)
            case .files:     FilesFocusSection()
            case .notes:     NotesFocusSection(notes: notes)
            case .research:  ResearchFocusSection()
            }
        }
        .navigationTitle(domain?.rawValue ?? "Active Focus")
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet()
        }
    }
}

// MARK: - Calendar Focus

private struct CalendarFocusSection: View {
    let meetings: [Meeting]
    private var todaysMeetings: [Meeting] {
        meetings.filter { Calendar.current.isDateInToday($0.startDate) }
    }
    var body: some View {
        List {
            if todaysMeetings.isEmpty {
                ContentUnavailableView("No meetings today", systemImage: "calendar", description: Text("Enjoy the free time."))
            } else {
                Section("Today") {
                    ForEach(todaysMeetings) { meeting in
                        MeetingRow(meeting: meeting)
                    }
                }
                let upcoming = meetings.filter { !Calendar.current.isDateInToday($0.startDate) && $0.startDate > .now }
                if !upcoming.isEmpty {
                    Section("Upcoming") {
                        ForEach(upcoming.prefix(5)) { meeting in
                            MeetingRow(meeting: meeting)
                        }
                    }
                }
            }
        }
    }
}

private struct MeetingRow: View {
    let meeting: Meeting
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(meeting.title).font(.callout.bold())
                Text(meeting.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(meeting.formattedDuration).font(.caption2).foregroundStyle(.tertiary)
            if meeting.isOngoing {
                Text("LIVE").font(.caption2.bold()).foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Tasks Focus

private struct TasksFocusSection: View {
    let tasks: [AgentTask]
    @Binding var showAddTask: Bool
    var body: some View {
        List {
            Section {
                Button { showAddTask = true } label: {
                    Label("Add Task", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
            let critical = tasks.filter { $0.priority >= .high }
            if !critical.isEmpty {
                Section("High Priority") {
                    ForEach(critical) { TaskRow(task: $0) }
                }
            }
            let normal = tasks.filter { $0.priority < .high }
            if !normal.isEmpty {
                Section("Other") {
                    ForEach(normal) { TaskRow(task: $0) }
                }
            }
            if tasks.isEmpty {
                ContentUnavailableView("All done!", systemImage: "checkmark.circle.fill",
                                       description: Text("No open tasks."))
            }
        }
    }
}

private struct TaskRow: View {
    @Environment(\.modelContext) private var modelContext
    let task: AgentTask
    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation { task.isCompleted = true }
            } label: {
                Image(systemName: "circle").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).font(.callout)
                if let proj = task.project {
                    Text(proj.name).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let dl = task.deadline {
                DeadlineBadge(deadline: dl)
            }
        }
    }
}

private struct DeadlineBadge: View {
    let deadline: Deadline
    var body: some View {
        Text(deadline.daysRemaining >= 0 ? "in \(deadline.daysRemaining)d" : "\(abs(deadline.daysRemaining))d late")
            .font(.caption2.bold())
            .foregroundStyle(deadline.urgencyLevel == .overdue ? .red : deadline.urgencyLevel == .critical ? .orange : .secondary)
    }
}

// MARK: - Mail Focus

private struct MailFocusSection: View {
    var body: some View {
        ContentUnavailableView {
            Label("Mail Overview", systemImage: "envelope.fill")
        } description: {
            Text("Ask AgentOS about your emails using the chat panel →")
        }
    }
}

// MARK: - Files Focus

private struct FilesFocusSection: View {
    var body: some View {
        ContentUnavailableView {
            Label("Files Search", systemImage: "folder.fill")
        } description: {
            Text("Try: \"Hey AgentOS, find my Berlin project presentation\"")
        }
    }
}

// MARK: - Notes Focus

private struct NotesFocusSection: View {
    let notes: [AgentNote]
    var body: some View {
        List(Array(notes.prefix(20))) { note in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title).font(.callout.bold())
                    Spacer()
                    Image(systemName: note.source.systemImage).foregroundStyle(.secondary).font(.caption)
                }
                Text(String(note.content.prefix(80)) + "…").font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                if !note.tags.isEmpty {
                    HStack {
                        ForEach(note.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)").font(.caption2).foregroundStyle(.tint)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Research Focus

private struct ResearchFocusSection: View {
    var body: some View {
        ContentUnavailableView {
            Label("Research", systemImage: "globe.americas.fill")
        } description: {
            Text("Ask a research question in the chat panel. Real-time queries use Gemini.")
        }
    }
}

// MARK: - Add Task Sheet

private struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title    = ""
    @State private var priority = AgentTask.TaskPriority.medium
    @State private var hasDue   = false
    @State private var dueDate  = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Task").font(.title2.bold())
            TextField("Task title", text: $title)
                .textFieldStyle(.roundedBorder)
            Picker("Priority", selection: $priority) {
                ForEach(AgentTask.TaskPriority.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Toggle("Has Deadline", isOn: $hasDue)
            if hasDue { DatePicker("Due date", selection: $dueDate, displayedComponents: .date) }
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Add") {
                    let task = AgentTask(title: title, priority: priority)
                    if hasDue {
                        let dl = Deadline(dueDate: dueDate)
                        task.deadline = dl
                        modelContext.insert(dl)
                    }
                    modelContext.insert(task)
                    dismiss()
                }
                .disabled(title.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
