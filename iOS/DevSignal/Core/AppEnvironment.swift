// PURPOSE:
//   Single source of truth for app-wide configuration.
//   Loads credentials from Keychain on init.
//   Falls back to hardcoded dev values if no Keychain entry exists.
//
// On first launch: no Keychain entry → isConfigured = false → show Onboarding
// After onboarding: Keychain entry saved → isConfigured = true → show main app

import Foundation
import SwiftUI

@Observable
class AppEnvironment {
    static let shared = AppEnvironment()

    var baseURL: String
    var apiKey: String
    var dataVersion: Int = 0

    // True when both values are set — drives onboarding vs main app routing
    var isConfigured: Bool {
        !baseURL.isEmpty && !apiKey.isEmpty
    }

    private init() {
        // Load from Keychain — returns nil if first launch
        self.baseURL = KeychainManager.load(.baseURL) ?? ""
        self.apiKey  = KeychainManager.load(.apiKey)  ?? ""
    }

    // ── Called after successful onboarding validation ─────────────────────

    func saveCredentials(baseURL: String, apiKey: String) throws {
        try KeychainManager.save(baseURL, for: .baseURL)
        try KeychainManager.save(apiKey,  for: .apiKey)
        self.baseURL = baseURL
        self.apiKey  = apiKey
    }

    // ── Reset (used in Settings → "Sign out") ────────────────────────────

    func clearCredentials() {
        KeychainManager.clearAll()
        self.baseURL = ""
        self.apiKey  = ""
    }

    func markDataUpdated() {
        dataVersion += 1
    }
}
