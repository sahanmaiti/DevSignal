// PURPOSE:
//   Accessible from the Home tab via a gear icon.
//   Shows server connection status, allows credential reset,
//   and provides app info.

import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                serverSection
                appSection
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
    }

    // ── Server section ────────────────────────────────────────────────────

    private var serverSection: some View {
        Section("Connection") {
            HStack {
                Label("Status", systemImage: "circle.fill")
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Connected")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }

            HStack {
                Label("Server", systemImage: "server.rack")
                Spacer()
                Text("DevSignal Cloud")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }


    // ── App section ───────────────────────────────────────────────────────

    private var appSection: some View {
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

#Preview {
    SettingsView()
        .environment(AppEnvironment.shared)
}
