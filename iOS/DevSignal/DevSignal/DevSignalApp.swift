import SwiftUI

@main
struct DevSignalApp: App {
    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            // Go straight to the main app — no onboarding screen.
            MainTabView()
                .environment(environment)
                .preferredColorScheme(.light)
        }
    }
}
