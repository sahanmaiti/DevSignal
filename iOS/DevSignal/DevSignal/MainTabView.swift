// MainTabView.swift
//
// PURPOSE:
//   The root view of the app. Contains a TabView with 5 tabs.
//   TabView is SwiftUI's equivalent of UITabBarController — it shows
//   the tab bar at the bottom with icons, and switches between screens.
//
// HOW TabView WORKS:
//   Each child view inside TabView becomes one tab.
//   The .tabItem modifier defines the icon and label for that tab.
//   SwiftUI automatically draws the tab bar — you just describe the tabs.

import SwiftUI

struct MainTabView: View {
    
    // @State tracks which tab is currently selected.
    // 0 = Home, 1 = Discover, 2 = Outreach, 3 = Tracker, 4 = Analytics
    // SwiftUI redraws the tab bar whenever this changes.
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // ── Tab 1: Home ──────────────────────────────────────────────
            // $selectedTab is a "binding" — a two-way connection to the
            // selectedTab variable. The TabView can both READ it (to know
            // which tab to show) and WRITE to it (when the user taps a tab).
            // The $ prefix creates a binding from a @State variable.
            
            HomeView()
                    .tabItem {
                        Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                    }
                    .tag(0)

                DiscoverView()
                    .tabItem {
                        Label("Discover", systemImage: selectedTab == 1 ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    }
                    .tag(1)

                OutreachView()
                    .tabItem {
                        Label("Outreach", systemImage: selectedTab == 2 ? "envelope.fill" : "envelope")
                    }
                    .tag(2)

                TrackerView()
                    .tabItem {
                        Label("Tracker", systemImage: selectedTab == 3 ? "checklist" : "checklist")
                    }
                    .tag(3)

                AnalyticsView()
                    .tabItem {
                        Label("Analytics", systemImage: selectedTab == 4 ? "chart.bar.fill" : "chart.bar")
                    }
                    .tag(4)
            }
            .tint(.dsAccent)
    }
}

// PREVIEW
// #Preview is a macro that shows a live preview of this view in Xcode.
// It appears in the canvas on the right side of Xcode.
// Changes you make update the preview instantly — no need to run the simulator.
#Preview {
    MainTabView()
        .environment(AppEnvironment.shared)
}
