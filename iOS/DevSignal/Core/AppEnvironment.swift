import Foundation
import SwiftUI

@Observable
class AppEnvironment {
    static let shared = AppEnvironment()

    // Points directly at our hosted backend — no user configuration needed.
    var baseURL: String = AppConfig.baseURL

    // Always true — app works immediately after install with no setup screen.
    var isConfigured: Bool { true }

    // Triggers cross-tab data refresh (used after pipeline runs)
    var dataVersion: Int = 0

    private init() {}

    // Returns the hardcoded API key from AppConfig.
    // This method signature is unchanged so APIClient.swift needs no edits.
    func currentAPIKey() -> String {
        return AppConfig.apiKey
    }

    // These are no-ops now — kept so any remaining call sites still compile.
    func saveCredentials(baseURL: String, apiKey: String) throws {}
    func clearCredentials() {}

    func markDataUpdated() {
        dataVersion += 1
    }
}
