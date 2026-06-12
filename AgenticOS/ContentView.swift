//
//  ContentView.swift
//  AgenticOS
//
//  Created by Venkat Chavan on 11/06/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        DashboardView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AgentTask.self, Project.self, Person.self,
                               AgentEmail.self, AgentFile.self, AgentNote.self,
                               Deadline.self, Meeting.self], inMemory: true)
}
