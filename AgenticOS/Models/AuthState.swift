// Models/AuthState.swift – AgentOS
// Sign in with Apple authentication state
// UserID stored in Keychain; verified on every launch via ASAuthorizationAppleIDProvider

import Foundation
import AuthenticationServices
import Observation

@Observable
final class AuthState {

    static let shared = AuthState()

    private(set) var isSignedIn: Bool = false
    private(set) var userName:   String = ""
    private(set) var userEmail:  String = ""

    private init() {
        loadFromKeychain()
    }

    // MARK: - Keychain Persistence

    private func loadFromKeychain() {
        guard let userID = KeychainHelper.read(key: "agentos.apple.userid") else {
            isSignedIn = false
            return
        }
        // Verify the credential is still valid with Apple
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userID) { [weak self] state, _ in
            DispatchQueue.main.async {
                self?.isSignedIn = (state == .authorized)
            }
        }
        userName  = KeychainHelper.read(key: "agentos.apple.name")  ?? ""
        userEmail = KeychainHelper.read(key: "agentos.apple.email") ?? ""
    }

    // MARK: - Sign In

    func handleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        KeychainHelper.write(key: "agentos.apple.userid", value: credential.user)

        if let fullName = credential.fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !name.isEmpty {
                KeychainHelper.write(key: "agentos.apple.name", value: name)
                userName = name
            }
        }
        if let email = credential.email, !email.isEmpty {
            KeychainHelper.write(key: "agentos.apple.email", value: email)
            userEmail = email
        }
        userName  = KeychainHelper.read(key: "agentos.apple.name")  ?? "User"
        userEmail = KeychainHelper.read(key: "agentos.apple.email") ?? ""
        isSignedIn = true
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainHelper.delete(key: "agentos.apple.userid")
        KeychainHelper.delete(key: "agentos.apple.name")
        KeychainHelper.delete(key: "agentos.apple.email")
        isSignedIn = false
        userName   = ""
        userEmail  = ""
    }
}
