// Features/Tracker/TrackerView.swift
//
// PURPOSE:
//   The Tracker tab. Will show a Kanban board of job applications.
//   For now it shows an empty state with the stage columns defined
//   so we understand the data model early.
//
// APPLICATION STAGES (defined here as a Swift enum):
//   Enum = a type with a fixed set of possible values.
//   Like Python's Enum but with more features.
//   CaseIterable means you can loop over all cases: ApplicationStage.allCases

import SwiftUI

// Defines all possible stages in the application lifecycle.
// This enum is defined at file scope (outside the view struct)
// so it can be used by multiple views later.
enum ApplicationStage: String, CaseIterable, Identifiable {
    case applied   = "applied"
    case waiting   = "waiting"
    case replied   = "replied"
    case interview = "interview"
    case offer     = "offer"
    case rejected  = "rejected"
    
    // Identifiable requires an `id` property — we use the rawValue string
    var id: String { rawValue }
    
    // Human-readable label shown in the UI
    var displayName: String {
        switch self {
        case .applied:   return "Applied"
        case .waiting:   return "Waiting"
        case .replied:   return "Replied"
        case .interview: return "Interview"
        case .offer:     return "Offer 🎉"
        case .rejected:  return "Rejected"
        }
    }
    
    // Color associated with each stage
    var color: Color {
        switch self {
        case .applied:   return .indigo
        case .waiting:   return .orange
        case .replied:   return .blue
        case .interview: return .purple
        case .offer:     return .green
        case .rejected:  return .red
        }
    }
    
    // SF Symbol icon for each stage
    var icon: String {
        switch self {
        case .applied:   return "paperplane.fill"
        case .waiting:   return "clock.fill"
        case .replied:   return "message.fill"
        case .interview: return "person.fill"
        case .offer:     return "star.fill"
        case .rejected:  return "xmark.circle.fill"
        }
    }
}

struct TrackerView: View {
    var body: some View {
        NavigationStack {
            // Horizontal scroll showing one column per stage
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    // ForEach over all stages — creates one column per stage
                    // ApplicationStage.allCases = [.applied, .waiting, .replied, ...]
                    ForEach(ApplicationStage.allCases) { stage in
                        StageColumn(stage: stage, cards: [])
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .navigationTitle("Tracker")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct StageColumn: View {
    let stage: ApplicationStage
    let cards: [String]   // will be [Application] in Phase 6 — String placeholder for now
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            // ── Column header ─────────────────────────────────────────────
            HStack {
                Image(systemName: stage.icon)
                    .foregroundStyle(stage.color)
                Text(stage.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                // Card count badge
                Text("\(cards.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(stage.color.opacity(0.15))
                    .foregroundStyle(stage.color)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            // ── Cards ─────────────────────────────────────────────────────
            if cards.isEmpty {
                // Empty column placeholder
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .frame(height: 80)
                    .overlay(
                        Text("No applications")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    )
                    .padding(.horizontal, 12)
            }
        }
        .frame(width: 200)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, 12)
    }
}

#Preview {
    TrackerView()
}
