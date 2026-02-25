import SwiftUI

// MARK: - Animated atmospheric background

private struct AnimatedBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.versoBackground

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.versoJade.opacity(0.10), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(
                    x: animate ? 50 : -50,
                    y: animate ? -30 : 40
                )
                .blur(radius: 30)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.versoSilver.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(
                    x: animate ? -40 : 30,
                    y: animate ? 50 : -20
                )
                .blur(radius: 25)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var seerrURL = ""
    @State private var seerrApiKey = ""
    @State private var showJellyseerr = false
    @State private var prograrURL = ""
    @State private var prograrApiKey = ""
    @State private var showPrograrr = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var headerScale: CGFloat = 0.8
    @State private var headerOpacity: Double = 0
    @State private var formOpacity: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()

                ScrollView {
                    VStack(spacing: VersoSpacing.xl) {
                        // Header
                        VStack(spacing: VersoSpacing.sm) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.versoJade, .versoSilver],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .scaleEffect(headerScale)
                                .opacity(headerOpacity)

                            Text("Verso")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)

                            Text("Connect to your Jellyfin server")
                                .font(.subheadline)
                                .foregroundStyle(Color.versoSecondaryText)
                        }
                        .padding(.top, 48)
                        .onAppear {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                headerScale = 1.0
                                headerOpacity = 1.0
                            }
                            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                                formOpacity = 1.0
                            }
                        }

                        // Glassmorphic form card
                        VStack(spacing: VersoSpacing.lg) {
                            VStack(spacing: VersoSpacing.md) {
                                styledTextField("Server URL", text: $serverURL)
                                    .textContentType(.URL)
                                    .keyboardType(.URL)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)

                                styledTextField("Username", text: $username)
                                    .textContentType(.username)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)

                                styledSecureField("Password", text: $password)
                                    .textContentType(.password)
                            }

                            DisclosureGroup("Jellyseerr (Optional)", isExpanded: $showJellyseerr) {
                                VStack(spacing: VersoSpacing.md) {
                                    styledTextField("Jellyseerr URL", text: $seerrURL)
                                        .textContentType(.URL)
                                        .keyboardType(.URL)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)

                                    styledSecureField("API Key", text: $seerrApiKey)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                }
                                .padding(.top, VersoSpacing.sm)
                            }
                            .foregroundStyle(Color.versoSecondaryText)
                            .tint(Color.versoJade)

                            DisclosureGroup("Prograrr (Optional)", isExpanded: $showPrograrr) {
                                VStack(spacing: VersoSpacing.md) {
                                    styledTextField("Prograrr URL", text: $prograrURL)
                                        .textContentType(.URL)
                                        .keyboardType(.URL)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)

                                    styledSecureField("API Key (Optional)", text: $prograrApiKey)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                }
                                .padding(.top, VersoSpacing.sm)
                            }
                            .foregroundStyle(Color.versoSecondaryText)
                            .tint(Color.versoJade)
                        }
                        .padding(VersoSpacing.lg)
                        .glassmorphic(cornerRadius: 24, borderOpacity: 0.06, glowColor: .versoJade, glowIntensity: 0.04)
                        .opacity(formOpacity)

                        // Error message
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.callout)
                                .multilineTextAlignment(.center)
                        }

                        // Login button
                        Button(action: login) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [.versoJade, .versoSilver],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .versoJade.opacity(0.25), radius: 12, y: 6)
                        .disabled(isLoading || serverURL.isEmpty || username.isEmpty)
                        .opacity(isLoading || serverURL.isEmpty || username.isEmpty ? 0.6 : 1.0)
                        .opacity(formOpacity)
                        .sensoryFeedback(.impact(weight: .medium), trigger: isLoading)
                    }
                    .padding(.horizontal, VersoSpacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func styledTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(VersoSpacing.md)
            .background(Color.versoCard)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.versoCardBorder, lineWidth: 1)
            )
    }

    private func styledSecureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .padding(VersoSpacing.md)
            .background(Color.versoCard)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.versoCardBorder, lineWidth: 1)
            )
    }

    private func login() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.login(
                    serverURL: serverURL,
                    username: username,
                    password: password,
                    seerrURL: showJellyseerr ? seerrURL : nil,
                    seerrApiKey: showJellyseerr ? seerrApiKey : nil,
                    prograrURL: showPrograrr ? prograrURL : nil,
                    prograrApiKey: showPrograrr ? prograrApiKey : nil
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
