// Shared/Components/ScoreBadge.swift
//
// PURPOSE:
//   A reusable score badge — the colored number shown on every job card.
//   Score 0-39: red, 40-59: orange, 60-79: yellow, 80-100: green
//
//   "Reusable component" means: defined once, used everywhere.
//   In Phase 3 both HomeView and DiscoverView will show this badge.
//
// NEW CONCEPT — Computed properties with logic:
//   Swift lets you put logic inside computed properties.
//   This is idiomatic Swift — don't use functions when a property works.

import SwiftUI

struct ScoreBadge: View {
    let score: Int
    
    // Color changes based on score range
    private var badgeColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80:  return Color(red: 0.6, green: 0.8, blue: 0.2)  // yellow-green
        case 40..<60:  return .orange
        default:       return .red
        }
    }
    
    var body: some View {
        Text("\(score)")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(badgeColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// You can preview a component in isolation like this:
#Preview("Score variations") {
    HStack(spacing: 12) {
        ScoreBadge(score: 92)
        ScoreBadge(score: 74)
        ScoreBadge(score: 55)
        ScoreBadge(score: 28)
    }
    .padding()
}
