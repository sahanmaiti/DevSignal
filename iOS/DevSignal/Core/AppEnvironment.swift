import Foundation
import SwiftUI

@Observable
class AppEnvironment {
    static let shared = AppEnvironment()

    // ── baseURL remains observable — it is not a secret ──────────────────
    var baseURL: String

    // ── isConfigured drives onboarding vs main-app routing ───────────────
    // Computed from Keychain state so it stays accurate even if the key is
    // deleted externally (e.g. the user resets the device backup).
    var isConfigured: Bool {
        !baseURL.isEmpty && KeychainManager.load(.apiKey) != nil
    }

    // ── dataVersion drives cross-tab refresh ─────────────────────────────
    var dataVersion: Int = 0

    private init() {
        self.baseURL = KeychainManager.load(.baseURL) ?? ""
        // DO NOT read the API key here.  It stays in the Keychain.
    }

    // ─────────────────────────────────────────────────────────────────────
    // API KEY ACCESS — the ONLY way to read the key outside this file
    //
    // This method is intentionally NOT a var, NOT @Published, and NOT part
    // of the @Observable observation graph.  That means:
    //   • SwiftUI never reads it during view updates
    //   • It never appears in `.description` output
    //   • It is not captured by `print(env)` or crash reporters
    //
    // Usage in APIClient:
    //   request.setValue(AppEnvironment.shared.currentAPIKey(), forHTTPHeaderField: "X-API-Key")
    // ─────────────────────────────────────────────────────────────────────

    func currentAPIKey() -> String {
        // Returns "" rather than nil so callers never crash on a missing key.
        // An empty key will simply receive a 401 from the server, which
        // triggers the normal "unauthorized" error path in APIClient.
        return KeychainManager.load(.apiKey) ?? ""
    }

    // ─────────────────────────────────────────────────────────────────────
    // CREDENTIAL LIFECYCLE
    // ─────────────────────────────────────────────────────────────────────

    /// Called by OnboardingView after a successful /stats validation.
    func saveCredentials(baseURL: String, apiKey: String) throws {
        try KeychainManager.save(baseURL, for: .baseURL)
        try KeychainManager.save(apiKey,  for: .apiKey)
        // Only the non-secret baseURL is stored in observable state.
        self.baseURL = baseURL
    }

    /// Called by SettingsView → "Reset Connection".
    func clearCredentials() {
        KeychainManager.clearAll()
        self.baseURL = ""
        // No apiKey property to clear — it only exists in the Keychain.
    }

    /// Triggers cross-tab data refresh (called after pipeline run, etc.)
    func markDataUpdated() {
        dataVersion += 1
    }
}
