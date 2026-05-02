// Features/Discover/DiscoverView.swift
//
// PURPOSE:
//   The Discover tab. This will show the full paginated job list
//   with search and filters. For now it's a placeholder.
//
// NEW CONCEPT — List:
//   List is SwiftUI's equivalent of UITableView.
//   It renders rows efficiently — only visible rows are in memory.
//   It automatically adds dividers, handles scroll, and supports
//   swipe actions. Much simpler than building a custom ScrollView.

import SwiftUI

struct DiscoverView: View {
    
    // @State private var searchText = ""
    // We'll add search in Phase 3. Commented out for now.
    
    var body: some View {
        NavigationStack {
            // Placeholder list — 8 skeleton rows
            List {
                ForEach(1...8, id: \.self) { _ in
                    DiscoverPlaceholderRow()
                        .listRowSeparator(.hidden)      // hide the default divider
                        .listRowBackground(Color.clear) // transparent row background
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }
            .listStyle(.plain)
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            // We'll add a toolbar filter button in Phase 3
        }
    }
}

struct DiscoverPlaceholderRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 15)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 140, height: 12)
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 60, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 50, height: 10)
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 40, height: 40)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    DiscoverView()
}
