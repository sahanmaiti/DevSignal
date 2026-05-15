import SwiftUI

struct OnboardingView: View {

    @Environment(AppEnvironment.self) private var env

    @State private var serverURL = "http://127.0.0.1:8000"
    @State private var apiKey = ""

    @State private var isValidating = false
    @State private var errorMessage: String? = nil
    @State private var currentStep = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.15), Color.dsPlainBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if currentStep == 0 {
                welcomeStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .leading)
                    ))
            } else {
                setupStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: currentStep)
    }

    // ── Step 0: Welcome ───────────────────────────────────────────────────

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 110, height: 110)
                    .shadow(color: .indigo.opacity(0.4), radius: 20, y: 8)

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 32)

            Text("DevSignal")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)

            Text("Your personal iOS internship radar.\nPowered by AI, runs every 12 hours.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 48)

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "magnifyingglass", color: .blue,
                           title: "13+ Job Sources",
                           subtitle: "RemoteOK, HackerNews, YC, Wellfound & more")
                FeatureRow(icon: "brain", color: .purple,
                           title: "AI Scoring",
                           subtitle: "Every job scored 0-100 across 8 factors")
                FeatureRow(icon: "envelope.fill", color: .indigo,
                           title: "Recruiter Outreach",
                           subtitle: "Personalised messages generated for you")
                FeatureRow(icon: "checklist", color: .green,
                           title: "Application Tracker",
                           subtitle: "Kanban board to track every stage")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)

            Spacer()

            Button {
                withAnimation { currentStep = 1 }
            } label: {
                HStack {
                    Text("Get Started").fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .indigo.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // ── Step 1: Server setup ──────────────────────────────────────────────

    private var setupStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                Button {
                    withAnimation { currentStep = 0 }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Connect Your Server")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Enter your DevSignal API server details. Your credentials are stored securely in the iOS Keychain.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Server URL", systemImage: "server.rack")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    TextField("http://127.0.0.1:8000", text: $serverURL)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .padding(14)
                        .background(Color.dsGroupedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                        )

                    Text("Use your Mac's local IP (e.g. 192.168.x.x) for a real device, or 127.0.0.1 for the Simulator.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("API Key", systemImage: "key.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    SecureField("your-api-key", text: $apiKey)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(14)
                        .background(Color.dsGroupedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                        )

                    Text("This matches PIPELINE_API_KEY in your .env file.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    Task { await validateAndConnect() }
                } label: {
                    HStack {
                        if isValidating {
                            ProgressView().tint(.white).scaleEffect(0.85)
                            Text("Connecting…").fontWeight(.semibold)
                        } else {
                            Image(systemName: "bolt.fill")
                            Text("Connect").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canConnect ? Color.indigo : Color.secondary.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!canConnect || isValidating)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Don't have a server yet?")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    Text("Run `bash api/start.sh` in your DevSignal project folder, then come back here.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color.dsGroupedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(24)
        }
    }

    // ── Validation ────────────────────────────────────────────────────────

    private var canConnect: Bool {
        !serverURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func validateAndConnect() async {
        isValidating = true
        errorMessage = nil

        let trimmedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            // Temporary Keychain write so APIClient can read the key during
            // the health check below.
            try KeychainManager.save(trimmedURL, for: .baseURL)
            try KeychainManager.save(trimmedKey, for: .apiKey)

            // Update the observable baseURL so APIClient.makeRequest() can
            // construct the correct URL.  The key itself stays in Keychain.
            env.baseURL = trimmedURL

        } catch {
            errorMessage = "Couldn't write credentials to Keychain. Try again."
            isValidating = false
            return
        }

        let isReachable = await APIClient.shared.checkHealth()

        if isReachable {
            // Keychain already has the correct values from the write above.
            // AppEnvironment.isConfigured will now return true and AppRouter
            // will switch to MainTabView automatically.
        } else {
            // Validation failed — wipe the temporary Keychain entries.
            KeychainManager.clearAll()
            env.baseURL    = ""
            errorMessage = "Couldn't reach the server. Check the URL and make sure `bash api/start.sh` is running."
        }

        isValidating = false
    }
}

// ── Feature row for welcome screen ───────────────────────────────────────────

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppEnvironment.shared)
}
