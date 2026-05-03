// Features/Discover/JobDetailView.swift
//
// PURPOSE:
//   Shows full details for a single job when tapped from DiscoverView.
//   Pushed onto the NavigationStack (like opening a new page).
//
// WHAT'S SHOWN:
//   - Company + title header
//   - Score breakdown bar chart (manual bars — no Charts framework needed yet)
//   - Job attributes: remote, visa, experience, source
//   - Apply button → calls POST /jobs/{id}/apply
//   - Link to open the job URL in Safari

import SwiftUI

struct JobDetailView: View {
    let job: Job
    
    @State private var isApplying = false
    @State private var applied = false
    @State private var applyError: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // ── Header ────────────────────────────────────────────────
                headerSection
                
                // ── Score breakdown ───────────────────────────────────────
                if let breakdown = job.scoreBreakdown {
                    scoreBreakdownSection(breakdown: breakdown)
                }
                
                // ── Attributes ────────────────────────────────────────────
                attributesSection
                
                // ── Apply button ──────────────────────────────────────────
                applySection
                
                // ── Open in browser ───────────────────────────────────────
                if let url = URL(string: job.url) {
                    Link(destination: url) {
                        Label("Open Full Job Listing", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(job.company)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // ── Subviews ──────────────────────────────────────────────────────────
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            CompanyAvatar(company: job.company)
                .scaleEffect(1.3)
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(job.title)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(job.company)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            ScoreBadge(score: job.displayScore)
                .scaleEffect(1.2)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func scoreBreakdownSection(breakdown: ScoreBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Breakdown")
                .font(.headline)
            
            ForEach(breakdown.factors, id: \.name) { factor in
                HStack {
                    Text(factor.name)
                        .font(.caption)
                        .frame(width: 90, alignment: .leading)
                    
                    // Progress bar — width proportional to points earned
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.15))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(factor.points > 0 ? Color.indigo : Color.secondary.opacity(0.3))
                                .frame(width: factor.points > 0 ? geo.size.width * CGFloat(factor.points) / 20.0 : 4)
                        }
                    }
                    .frame(height: 8)
                    
                    Text("+\(factor.points)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(factor.points > 0 ? .indigo : .secondary)
                        .frame(width: 32, alignment: .trailing)
                }
            }
            
            Divider()
            
            HStack {
                Text("Total Score")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(job.displayScore) / 100")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.indigo)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var attributesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details")
                .font(.headline)
            
            AttributeRow(icon: "location.fill",     label: "Location",   value: job.location ?? "Not specified", color: .pink)
            AttributeRow(icon: "clock.fill",         label: "Posted",     value: job.postedAgoText, color: .orange)
            AttributeRow(icon: "wifi",               label: "Remote",     value: job.isRemote == true ? "Yes" : "No", color: .green)
            AttributeRow(icon: "doc.text.fill",      label: "Experience", value: job.experienceRequired ?? "Not specified", color: .blue)
            AttributeRow(icon: "airplane",           label: "Visa",       value: job.visaSponsorship == true ? "Sponsored" : "Not specified", color: .purple)
            AttributeRow(icon: "app.badge.fill",     label: "Source",     value: job.sourceDisplay, color: .indigo)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var applySection: some View {
        VStack(spacing: 10) {
            if let error = applyError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            Button {
                Task { await markApplied() }
            } label: {
                HStack {
                    if isApplying {
                        ProgressView().tint(.white)
                    } else if applied || job.isApplied {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Applied")
                    } else {
                        Image(systemName: "paperplane.fill")
                        Text("Mark as Applied")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(applied || job.isApplied ? Color.green : Color.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isApplying || applied || job.isApplied)
        }
    }
    
    private func markApplied() async {
        isApplying = true
        applyError = nil
        do {
            try await APIClient.shared.applyToJob(jobId: job.id, stage: "applied")
            applied = true
        } catch let apiError as APIError {
            applyError = apiError.errorDescription
        } catch {
            applyError = error.localizedDescription
        }
        isApplying = false
    }
}

struct AttributeRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
        }
    }
}
