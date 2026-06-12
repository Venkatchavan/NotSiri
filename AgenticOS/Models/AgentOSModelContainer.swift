// Models/AgentOSModelContainer.swift – AgentOS
// Global singleton reference to the shared SwiftData ModelContainer.
// Set once in AgenticOSApp.init(); consumed by background engines
// (ProactiveIntelligenceEngine, FileIndexer) that run outside the SwiftUI view tree.

import Foundation
import SwiftData

final class AgentOSModelContainer {

    // Set by AgenticOSApp immediately after the container is built
    static var _container: ModelContainer?

    static func shared() throws -> ModelContainer {
        guard let c = _container else { throw ContainerError.notInitialized }
        return c
    }

    enum ContainerError: Error {
        case notInitialized
    }
}
