// PURPOSE:
//   Components that are used across multiple views.
//   Centralising them here means no view file needs to define
//   its own copy — they all import from here automatically.
//
//   Components moved here from Phase 2:
//     - StatCard          (used by HomeView)
//     - PlaceholderJobCard (used by HomeView)
//     - DiscoverPlaceholderRow (used by DiscoverView skeleton)

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// StatCard
// The three KPI cards on the Home tab (Total Jobs, Applied, Score ≥70)
// ─────────────────────────────────────────────────────────────────────────────

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlaceholderJobCard
// Grey shimmer card shown on Home while top jobs are loading
// ─────────────────────────────────────────────────────────────────────────────

struct PlaceholderJobCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 120, height: 12)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 36, height: 36)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// DiscoverPlaceholderRow
// Grey shimmer row shown in Discover list while the first page is loading
// ─────────────────────────────────────────────────────────────────────────────

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

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 40, height: 40)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Previews
// ─────────────────────────────────────────────────────────────────────────────

#Preview("StatCard") {
    HStack(spacing: 12) {
        StatCard(title: "Total Jobs", value: "247", color: .indigo)
        StatCard(title: "Applied",    value: "12",  color: .green)
        StatCard(title: "Score ≥70",  value: "43",  color: .orange)
    }
    .padding()
}

#Preview("Placeholders") {
    VStack(spacing: 12) {
        PlaceholderJobCard()
        DiscoverPlaceholderRow()
    }
    .padding()
}
