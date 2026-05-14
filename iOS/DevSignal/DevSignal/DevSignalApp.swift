// PURPOSE:
//   App entry point. Checks if credentials exist in Keychain.
//   If yes → show main TabView.
//   If no  → show OnboardingView.
//
// The switch between onboarding and main app is driven by
// AppEnvironment.isConfigured. When onboarding saves credentials,
// isConfigured becomes true and SwiftUI automatically shows MainTabView.

import SwiftUI

@main
struct DevSignalApp: App {
    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(environment)
        }
    }
}

struct AppRouter: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            if env.isConfigured {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.light)
    }
}
