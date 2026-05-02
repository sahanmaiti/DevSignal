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

@Observable
class AppEnvironment {
    
    // The base URL of your FastAPI server.
    // During development this points to localhost (your Mac).
    // The iOS Simulator on the same Mac can reach localhost directly.
    // For a real device, you'd use your Mac's local IP (e.g. 192.168.1.x)
    var baseURL: String = "http://127.0.0.1:8000"
    
    // The API key that matches PIPELINE_API_KEY in your .env file
    var apiKey: String = "devsignal-local-key-2024"
    
    // isConfigured: true when both URL and key are set.
    // We'll use this later to show an onboarding screen on first launch.
    var isConfigured: Bool {
        !baseURL.isEmpty && !apiKey.isEmpty
    }
    
    // Singleton: one shared instance for the whole app.
    // Any file can access AppEnvironment.shared
    static let shared = AppEnvironment()
    
    // Private init prevents accidental creation of extra instances
    private init() {}
}
