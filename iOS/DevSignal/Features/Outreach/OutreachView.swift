// Features/Outreach/OutreachView.swift
//
// PURPOSE:
//   The Outreach tab. Will show generated recruiter messages
//   with copy-to-clipboard and edit functionality.
//
// NEW CONCEPT — ContentUnavailableView:
//   This is Apple's standard empty-state view. Use it whenever
//   a list or screen has no content to show. It takes a title,
//   description, and optional action button.

import SwiftUI

struct OutreachView: View {
    var body: some View {
        NavigationStack {
            // Empty state — we have no data yet
            ContentUnavailableView(
                "No Outreach Messages",
                systemImage: "envelope.badge",
                description: Text("Messages will appear here once jobs are scored above 45 and enriched.")
            )
            .navigationTitle("Outreach")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    OutreachView()
}
