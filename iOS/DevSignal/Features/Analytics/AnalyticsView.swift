// Features/Analytics/AnalyticsView.swift
//
// PURPOSE:
//   The Analytics tab. Will show charts from GET /stats:
//   score distribution, source performance, application funnel.
//
// NEW CONCEPT — Swift Charts:
//   Apple's built-in charting framework (iOS 16+). We'll use it
//   in Phase 3. For now, placeholder stat cards.

import SwiftUI

struct AnalyticsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Pipeline health card
                    pipelineCard
                    
                    // Placeholder chart area
                    chartPlaceholder
                    
                    // Source performance placeholder
                    sourcePlaceholder
                }
                .padding(20)
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var pipelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pipeline Health", systemImage: "bolt.fill")
                .font(.headline)
            
            HStack(spacing: 0) {
                PipelineStat(label: "Total Jobs", value: "--")
                Divider().frame(height: 40)
                PipelineStat(label: "Avg Score", value: "--")
                Divider().frame(height: 40)
                PipelineStat(label: "Score ≥70", value: "--")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var chartPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Distribution")
                .font(.headline)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 180)
                .overlay(
                    Text("Chart loads in Phase 3")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                )
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var sourcePlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Sources")
                .font(.headline)
            ForEach(["RemoteOK", "HackerNews", "YC Startup", "Remotive"], id: \.self) { source in
                HStack {
                    Text(source)
                        .font(.subheadline)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 60, height: 10)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct PipelineStat: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AnalyticsView()
}
