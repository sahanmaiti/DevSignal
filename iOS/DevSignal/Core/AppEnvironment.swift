// PURPOSE:
//   A single place that holds app-wide configuration: the API base URL
//   and API key. Every part of the app that needs to make a network call
//   reads from this object.
//
// WHY A CLASS AND NOT A STRUCT?
//   We use `class` with @Observable so the same instance can be shared
//   across the whole app and any change (like updating the API key)
//   automatically updates every screen that reads from it.
//
// OBSERVABLE:
//   @Observable is Swift's modern way to make a class reactive.
//   When a property marked with @Observable changes, any SwiftUI view
//   that reads it will automatically redraw. Similar to @State but
//   for objects shared across multiple views.

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

    // The base URL of your FastAPI server.
    // During development this points to localhost (your Mac).
    // The iOS Simulator on the same Mac can reach localhost directly.
    // For a real device, you'd use your Mac's local IP (e.g. 192.168.1.x)
    var baseURL: String = "http://127.0.0.1:8000"

    // The API key that matches PIPELINE_API_KEY in your .env file
    var apiKey: String = "devsignal-local-key-2024"

    // Persisted appearance mode for a global light/dark/system override.
    var appearanceModeRaw: String = UserDefaults.standard.string(forKey: "appearance_mode") ?? AppearanceMode.system.rawValue {
        didSet {
            UserDefaults.standard.set(appearanceModeRaw, forKey: "appearance_mode")
        }
    }

    // isConfigured: true when both URL and key are set.
    // We'll use this later to show an onboarding screen on first launch.
    var isConfigured: Bool {
        !baseURL.isEmpty && !apiKey.isEmpty
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
        set { appearanceModeRaw = newValue.rawValue }
    }

    var preferredColorScheme: ColorScheme? {
        appearanceMode.colorScheme
    }

    // Singleton: one shared instance for the whole app.
    // Any file can access AppEnvironment.shared
    static let shared = AppEnvironment()

    // Private init prevents accidental creation of extra instances
    private init() {}
}
