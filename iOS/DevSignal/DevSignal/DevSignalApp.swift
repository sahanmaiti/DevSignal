// PURPOSE: App entry point. Sets up the environment and shows the root view.
//
// @main tells Swift "this struct is where the app starts"
// WindowGroup is SwiftUI's container for the main window

import SwiftUI

@main
struct DevSignalApp: App {
    
    // The shared environment object — created once here and passed
    // down to every view in the app automatically via .environment()
    private let environment = AppEnvironment.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                // .environment() injects the environment object into
                // the SwiftUI view hierarchy. Any child view can access
                // it with @Environment(AppEnvironment.self)
                .environment(environment)
        }
    }
}
