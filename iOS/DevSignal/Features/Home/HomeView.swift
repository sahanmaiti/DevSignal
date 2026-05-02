// PURPOSE:
//   The Home tab. This will eventually show:
//     - A greeting header with today's date
//     - KPI summary cards (total jobs, applied, interviews)
//     - A "top picks today" feed of high-scoring jobs
//
//   For now it's a placeholder so the app compiles and runs.
//   We fill in the real content in Phase 3 when we connect to the API.
//
// NEW SWIFT CONCEPTS IN THIS FILE:
//   VStack  — arranges children vertically (like a column in CSS flexbox)
//   HStack  — arranges children horizontally (like a row)
//   Spacer  — flexible empty space that pushes other views apart
//   ScrollView — makes content scrollable
//   .padding() — adds space around a view (like CSS padding)
//   .font()    — sets text size/weight
//   .foregroundStyle() — sets text/icon color

import SwiftUI

struct HomeView: View {
    var body: some View {
        // NavigationStack enables a navigation bar at the top
        // and allows pushing new screens onto a stack (like browser history)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // ── Greeting section ─────────────────────────────────
                    greetingSection
                    
                    // ── Stats row ────────────────────────────────────────
                    statsRow
                    
                    // ── Placeholder feed ─────────────────────────────────
                    placeholderFeed
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle("DevSignal")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // ── Subviews defined as computed properties ───────────────────────────
    // Breaking a view into smaller named pieces keeps body readable.
    // This is like defining helper functions in Python.
    
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.title2)
                .fontWeight(.semibold)
            Text("Here's your iOS job radar")
                .font(.subheadline)
                .foregroundStyle(.secondary)   // secondary = system gray
        }
    }
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "Total Jobs", value: "--", color: .indigo)
            StatCard(title: "Applied", value: "--", color: .green)
            StatCard(title: "Interviews", value: "--", color: .orange)
        }
    }
    
    private var placeholderFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Picks Today")
                .font(.headline)
            
            // ForEach repeats a view for each item in a collection.
            // 1...3 is a range: [1, 2, 3]
            // id: \.self means "use the number itself as the unique ID"
            ForEach(1...3, id: \.self) { _ in
                PlaceholderJobCard()
            }
        }
    }
    
    // Computed property: returns a greeting based on time of day
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning 👋"
        case 12..<17: return "Good afternoon 👋"
        default: return "Good evening 👋"
        }
    }
}

// ── Supporting views ──────────────────────────────────────────────────────
// Small reusable components defined in the same file for now.
// We'll move them to Shared/ when they're needed in multiple screens.

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)  // stretch to fill available width
        .padding(16)
        .background(color.opacity(0.08))   // very light tinted background
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PlaceholderJobCard: View {
    var body: some View {
        HStack(spacing: 12) {
            // Company logo placeholder — grey circle
            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                // Shimmer placeholder bars — grey rounded rectangles
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 120, height: 12)
            }
            
            Spacer()
            
            // Score placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 36, height: 36)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HomeView()
}
