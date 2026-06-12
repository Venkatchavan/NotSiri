// Views/SignInView.swift – AgentOS
// Full-screen Sign in with Apple onboarding screen

import SwiftUI
import AuthenticationServices

struct SignInView: View {

    @State private var authState = AuthState.shared
    @State private var errorMessage: String? = nil
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // ── Background gradient ──────────────────────────────────────
            LinearGradient(
                colors: [Color(hex: "#0A0E1A") ?? .black, Color(hex: "#0D1B3E") ?? .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle radial glow behind the icon
            RadialGradient(
                colors: [Color(hex: "#1A3A7A")!.opacity(0.4), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 280
            )
            .frame(width: 560, height: 560)
            .offset(y: -40)

            VStack(spacing: 0) {
                Spacer()

                // ── App Icon ─────────────────────────────────────────────
                ZStack {
                    Circle()
                        .fill(Color(hex: "#1A2E5A")!.opacity(0.6))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)

                    if let img = NSImage(named: "AppIcon") {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: Color(hex: "#4A9FFF")!.opacity(0.5), radius: 20)
                    } else {
                        // Fallback icon when asset not yet added
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#1A3A7A") ?? .blue, Color(hex: "#0D1B3E") ?? .black],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 100, height: 100)
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(
                                    LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom)
                                )
                        }
                        .shadow(color: .cyan.opacity(0.4), radius: 20)
                    }
                }
                .scaleEffect(isAnimating ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: isAnimating)
                .padding(.bottom, 32)

                // ── App Name ──────────────────────────────────────────────
                Text("AgentOS")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, Color(hex: "#A0C8FF") ?? .blue],
                                       startPoint: .leading, endPoint: .trailing)
                    )

                Text("Your personal AI chief of staff")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 6)
                    .padding(.bottom, 48)

                // ── Feature pills ─────────────────────────────────────────
                HStack(spacing: 20) {
                    FeaturePill(icon: "calendar", label: "Calendar")
                    FeaturePill(icon: "checkmark.circle", label: "Tasks")
                    FeaturePill(icon: "doc.text", label: "Files")
                    FeaturePill(icon: "mic.fill", label: "Voice")
                }
                .padding(.bottom, 52)

                // ── Sign in with Apple ─────────────────────────────────────
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
                        authState.handleCredential(credential)
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(width: 320, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .white.opacity(0.15), radius: 10)

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.top, 12)
                }

                // ── Privacy note ──────────────────────────────────────────
                Text("AgentOS never shares your data. All AI processing runs on‑device.\nYour Apple ID is used only to identify your account.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .padding(.top, 20)

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .frame(minWidth: 520, minHeight: 620)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Feature Pill

private struct FeaturePill: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.07), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
