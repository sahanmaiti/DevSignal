// PURPOSE:
//   Accessible from the Home tab via a gear icon.
//   Shows server connection status, allows credential reset,
//   and provides app info.

import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirm = false
    @State private var showServerInfo = false

    var body: some View {
        NavigationStack {
            List {
                serverSection
                appSection
                dangerSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.indigo)
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .confirmationDialog(
            "Reset Connection",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset and Re-connect", role: .destructive) {
                env.clearCredentials()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your saved credentials. You'll need to reconnect to your server.")
        }
    }

    // ── Server section ────────────────────────────────────────────────────

    private var serverSection: some View {
        Section("Server Connection") {
            HStack {
                Label("Status", systemImage: "circle.fill")
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(env.isConfigured ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(env.isConfigured ? "Connected" : "Not connected")
                        .font(.subheadline)
                        .foregroundStyle(env.isConfigured ? .green : .red)
                }
            }

            if env.isConfigured {
                HStack {
                    Label("Server", systemImage: "server.rack")
                    Spacer()
                    Text(env.baseURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Label("API Key", systemImage: "key.fill")
                    Spacer()
                    Text("••••••••")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // ── App section ───────────────────────────────────────────────────────

    private var appSection: some View {
        Group {
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { env.appearanceMode },
                    set: { env.updateAppearanceMode($0) }
                )) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("About") {
                HStack {
                    Label("Version", systemImage: "info.circle.fill")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Built by", systemImage: "person.fill")
                    Spacer()
                    Text("Sahan Maiti")
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://github.com/sahanmaiti/devsignal")!) {
                    Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
                        .foregroundStyle(.indigo)
                }
            }
        }
    }

    // ── Danger zone ───────────────────────────────────────────────────────

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Reset Connection", systemImage: "trash.fill")
            }
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("Resetting will remove your saved server URL and API key from the device Keychain.")
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppEnvironment.shared)
}
