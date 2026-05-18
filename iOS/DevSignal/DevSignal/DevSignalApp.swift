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
