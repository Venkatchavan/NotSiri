// AgenticOSWatch/WatchQueryProxy.swift
// Handles on-watch Foundation Models for simple queries
// Proxies complex queries to Mac via Multipeer Connectivity

import Foundation
import MultipeerConnectivity
import WatchKit

final class WatchQueryProxy: NSObject {

    static let shared = WatchQueryProxy()

    // Multipeer for Mac proxy
    private let serviceType = "agentos-watch"
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?
    private let localPeer = MCPeerID(displayName: WKInterfaceDevice.current().name)
    private var connectedMacPeer: MCPeerID?

    // Pending query continuations
    private var pendingContinuations: [UUID: CheckedContinuation<String, Error>] = [:]

    private override init() {
        super.init()
        setupMultipeer()
    }

    // MARK: - Public API

    func ask(_ query: String) async throws -> String {
        // 1. Try on-device if query is simple
        if isSimpleQuery(query) {
            return try await askOnDevice(query)
        }
        // 2. Proxy to Mac if connected
        if connectedMacPeer != nil {
            return try await proxyToMac(query)
        }
        // 3. Fallback to on-device regardless
        return try await askOnDevice(query)
    }

    // MARK: - On-Device (watchOS Foundation Models)

    private func askOnDevice(_ query: String) async throws -> String {
        // watchOS 27 Foundation Models on-device
        #if canImport(FoundationModels)
        let session = LanguageModelSession(instructions: "You are AgentOS, a personal assistant. Answer concisely for a Watch screen (max 2 sentences).")
        let response = try await session.respond(to: query)
        return response.content
        #else
        return "Foundation Models not available on this device."
        #endif
    }

    // MARK: - Mac Proxy via Multipeer

    private func proxyToMac(_ query: String) async throws -> String {
        guard let peer = connectedMacPeer, let mcSession = session else {
            throw WatchProxyError.notConnected
        }
        let queryID = UUID()
        let payload = WatchQueryPayload(id: queryID, query: query)
        let data = try JSONEncoder().encode(payload)

        return try await withCheckedThrowingContinuation { cont in
            pendingContinuations[queryID] = cont
            try? mcSession.send(data, toPeers: [peer], with: .reliable)
            // Timeout after 10s
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                if let cont = self?.pendingContinuations.removeValue(forKey: queryID) {
                    cont.resume(throwing: WatchProxyError.timeout)
                }
            }
        }
    }

    // MARK: - Multipeer Setup

    private func setupMultipeer() {
        session = MCSession(peer: localPeer, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self
        browser = MCNearbyServiceBrowser(peer: localPeer, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    // MARK: - Helpers

    private func isSimpleQuery(_ q: String) -> Bool {
        let simpleKeywords = ["next", "today", "what", "when", "how many", "brief"]
        return simpleKeywords.contains { q.localizedCaseInsensitiveContains($0) } && q.count < 80
    }
}

// MARK: - MCSession Delegate

extension WatchQueryProxy: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if state == .connected { connectedMacPeer = peerID }
        if state == .notConnected && connectedMacPeer == peerID { connectedMacPeer = nil }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let response = try? JSONDecoder().decode(WatchResponsePayload.self, from: data),
              let cont = pendingContinuations.removeValue(forKey: response.id) else { return }
        cont.resume(returning: response.answer)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCBrowser Delegate

extension WatchQueryProxy: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard let session else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        if connectedMacPeer == peerID { connectedMacPeer = nil }
    }
}

// MARK: - Payload Types

struct WatchQueryPayload: Codable {
    let id: UUID
    let query: String
}

struct WatchResponsePayload: Codable {
    let id: UUID
    let answer: String
}

enum WatchProxyError: Error {
    case notConnected, timeout
}

#if canImport(FoundationModels)
import FoundationModels
#endif
