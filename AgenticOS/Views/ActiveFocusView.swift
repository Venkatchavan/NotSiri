// Views/ActiveFocusView.swift – AgentOS
// Column 2: Domain-specific deep view for current focus area

import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

struct ActiveFocusView: View {

    let domain: AgentDomain?
    @Environment(\.modelContext) private var modelContext

    // Bare @Query avoids SwiftData generating a private parameterised init
    @Query private var allTasks: [AgentTask]
    @Query private var allMeetings: [Meeting]
    @Query private var allNotes: [AgentNote]
    @Query private var allFiles: [AgentFile]

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
    private var recentFiles: [AgentFile] {
        allFiles.sorted { $0.lastModified > $1.lastModified }
    }

    var body: some View {
        Group {
            switch domain ?? .tasks {
            case .calendar:  CalendarFocusSection(meetings: meetings)
            case .mail:      MailFocusSection()
            case .tasks:     TasksFocusSection(tasks: openTasks, showAddTask: $showingAddTask)
            case .files:     FilesFocusSection(files: recentFiles)
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
    @State private var toField      = ""
    @State private var subjectField = ""
    @State private var bodyField    = ""
    @State private var showCompose  = false

    var body: some View {
        List {
            // Compose row
            Section {
                Button {
                    showCompose = true
                } label: {
                    Label("Compose New Email", systemImage: "square.and.pencil")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Inbox Access", systemImage: "info.circle")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("macOS sandboxing prevents third-party apps from reading Mail.app's inbox directly. Use the Agent Chat to draft replies — AgentOS composes via your default mail client.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Quick Compose") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("To: (email address)", text: $toField)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    TextField("Subject", text: $subjectField)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    TextEditor(text: $bodyField)
                        .font(.caption)
                        .frame(height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                    Button("Open in Mail") {
                        openInMail(to: toField, subject: subjectField, body: bodyField)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(toField.isEmpty)
                    .font(.caption)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.inset)
    }

    private func openInMail(to: String, subject: String, body: String) {
        var components  = URLComponents()
        components.scheme = "mailto"
        components.path   = to
        var items: [URLQueryItem] = []
        if !subject.isEmpty { items.append(URLQueryItem(name: "subject", value: subject)) }
        if !body.isEmpty    { items.append(URLQueryItem(name: "body",    value: body))    }
        components.queryItems = items.isEmpty ? nil : items
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Files Focus

private struct FilesFocusSection: View {
    let files: [AgentFile]
    @State private var searchText = ""

    private var filtered: [AgentFile] {
        guard !searchText.isEmpty else { return Array(files.prefix(50)) }
        return files.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.fileExtension.localizedCaseInsensitiveContains(searchText) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        .prefix(50)
        .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
                TextField("Search files…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if files.isEmpty {
                ContentUnavailableView {
                    Label("No Files Indexed", systemImage: "folder.badge.questionmark")
                } description: {
                    Text("Files from Desktop, Documents and Downloads are indexed on launch. Try re-syncing with ↻ in the toolbar.")
                }
                Spacer()
            } else {
                List(filtered) { file in
                    FileRow(file: file)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct FileRow: View {
    let file: AgentFile

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName(for: file.fileExtension))
                .foregroundStyle(iconColor(for: file.fileExtension))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.callout)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !file.tags.isEmpty {
                        Text(file.tags.first ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(file.lastModified.relativeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                if !file.filePath.isEmpty {
                    NSWorkspace.shared.selectFile(file.filePath, inFileViewerRootedAtPath: "")
                } else if let url = file.resolveURL() {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                }
            } label: {
                Image(systemName: "arrow.right.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(.vertical, 2)
    }

    private func iconName(for ext: String) -> String {
        switch ext {
        case "pdf":                          return "doc.richtext"
        case "doc", "docx", "pages", "rtf": return "doc.text"
        case "xls", "xlsx", "csv", "numbers": return "tablecells"
        case "ppt", "pptx", "key":          return "person.wave.2"
        case "md", "txt":                   return "text.alignleft"
        case "swift", "py", "js", "ts":     return "chevron.left.forwardslash.chevron.right"
        case "json", "yaml", "yml", "xml":  return "curlybraces"
        case "png", "jpg", "jpeg", "heic":  return "photo"
        case "mp4", "mov":                  return "play.rectangle"
        case "mp3", "m4a":                  return "music.note"
        case "zip", "gz", "tar":            return "archivebox"
        default:                            return "doc"
        }
    }

    private func iconColor(for ext: String) -> Color {
        switch ext {
        case "pdf":                          return .red
        case "doc", "docx", "pages":        return .blue
        case "xls", "xlsx", "csv", "numbers": return .green
        case "ppt", "pptx", "key":          return .orange
        case "md", "txt", "rtf":            return .primary
        case "swift":                       return .orange
        case "py":                          return .blue
        case "js", "ts":                    return .yellow
        case "json", "yaml", "yml":         return .teal
        case "png", "jpg", "jpeg", "heic":  return .purple
        case "mp4", "mov":                  return .pink
        default:                            return .secondary
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
