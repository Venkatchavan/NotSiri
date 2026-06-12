// AI/FoundationModelsCompat.swift – AgentOS
//
// PURPOSE: Allows the project to compile on macOS 15 / Xcode 16 (e.g. CI runners)
// where the FoundationModels framework does not yet exist.
//
// On macOS 26+ the real FoundationModels framework is used automatically.
// On older SDKs these stubs satisfy the type-checker so the build succeeds;
// all stub methods are no-ops / return empty values.
//
// ⚠️  Never ship a release built against these stubs – they have no AI capability.

#if !canImport(FoundationModels)

import Foundation

// MARK: - Generable (stub protocol)

/// Mirrors the FoundationModels.Generable protocol.
/// The real @Generable macro generates conformance + JSON schema metadata;
/// the stub just requires a default initializer so we can return a value.
public protocol Generable: Sendable {
    init()
}

// MARK: - LanguageModelSession (stub)

public final class LanguageModelSession: @unchecked Sendable {

    public init(instructions: String = "") {}

    // MARK: Text response

    public struct Response<T: Sendable>: Sendable {
        public let content: T
    }

    /// Returns an empty string — stub only.
    public func respond(to prompt: String) async throws -> Response<String> {
        Response(content: "")
    }

    /// Returns a default-initialised T — stub only.
    public func respond<T: Generable>(
        to prompt: String,
        generating type: T.Type
    ) async throws -> Response<T> {
        Response(content: T())
    }
}

#endif
