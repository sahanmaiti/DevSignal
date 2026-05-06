// PURPOSE:
//   Single source of truth for app-wide configuration.
//   Loads credentials from Keychain on init.
//   Falls back to hardcoded dev values if no Keychain entry exists.
//
// On first launch: no Keychain entry → isConfigured = false → show Onboarding
// After onboarding: Keychain entry saved → isConfigured = true → show main app

import Foundation
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
class AppEnvironment {
    static let shared = AppEnvironment()

    var baseURL: String
    var apiKey: String
    var appearanceModeRaw: String
    var dataVersion: Int = 0

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
        set { appearanceModeRaw = newValue.rawValue }
    }

    // True when both values are set — drives onboarding vs main app routing
    var isConfigured: Bool {
        !baseURL.isEmpty && !apiKey.isEmpty
    }

    private init() {
        // Load from Keychain — returns nil if first launch
        self.baseURL = KeychainManager.load(.baseURL) ?? ""
        self.apiKey  = KeychainManager.load(.apiKey)  ?? ""
        self.appearanceModeRaw = UserDefaults.standard.string(forKey: "appearance_mode") ?? AppearanceMode.system.rawValue
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

    func updateAppearanceMode(_ mode: AppearanceMode) {
        appearanceModeRaw = mode.rawValue
        UserDefaults.standard.set(mode.rawValue, forKey: "appearance_mode")
    }

    func markDataUpdated() {
        dataVersion += 1
    }
}

