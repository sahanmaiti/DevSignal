// Features/Discover/JobDetailView.swift
//
// PURPOSE:
//   Full detail screen for a single job.
//   Enhanced in Phase 4 with:
//     - Description section (fetched from full job record)
//     - "View Outreach Message" button → opens OutreachDetailSheet
//     - Animated score bars
//     - Apply confirmation feedback

import SwiftUI

struct JobDetailView: View {
    let job: Job

    // We fetch the full job record again to get description
    // (the list endpoint omits it to keep payloads small)
    @State private var fullJob: Job? = nil
    @State private var outreach: OutreachMessage? = nil
    @State private var isLoadingDetail = false
    @State private var isApplying = false
    @State private var applied = false
    @State private var applyError: String? = nil
    @State private var showOutreachSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // ── Header ────────────────────────────────────────────────
                headerSection

                // ── Quick actions ─────────────────────────────────────────
                quickActionsRow

                // ── Score breakdown ───────────────────────────────────────
                if let breakdown = job.scoreBreakdown {
                    scoreBreakdownSection(breakdown: breakdown)
                }

                // ── Job attributes ────────────────────────────────────────
                attributesSection

                // ── Description (loaded async) ────────────────────────────
                descriptionSection

                // ── Outreach preview ──────────────────────────────────────
                if let outreach, outreach.hasContent {
                    outreachPreviewSection(outreach: outreach)
                }
            }
            .padding(20)
        }
        .navigationTitle(job.company ?? "Unknown Company")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
        .sheet(isPresented: $showOutreachSheet) {
            if let outreach {
                OutreachDetailSheet(job: job, outreach: outreach)
            }
        }
    }

    // ── Header ────────────────────────────────────────────────────────────

    private var headerSection: some View {
        HStack(spacing: 16) {
            CompanyAvatar(company: job.company ?? "Unknown Company")
                .scaleEffect(1.4)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 5) {
                Text(job.displayTitle)
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(2)
                Text(job.company ?? "Unknown Company")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    if job.isRemote == true {
                        PillBadge(text: "Remote", color: .green)
                    }
                    if job.visaSponsorship == true {
                        PillBadge(text: "Visa", color: .blue)
                    }
                    PillBadge(text: job.sourceDisplay, color: .indigo)
                }
            }

            Spacer()

            VStack(spacing: 4) {
                ScoreBadge(score: job.displayScore)
                Text("score")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // ── Quick actions row ─────────────────────────────────────────────────

    private var quickActionsRow: some View {
        HStack(spacing: 10) {

            // Apply button
            Button {
                Task { await markApplied() }
            } label: {
                HStack(spacing: 6) {
                    if isApplying {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: applied || job.isApplied ? "checkmark.circle.fill" : "paperplane.fill")
                    }
                    Text(applied || job.isApplied ? "Applied" : "Apply")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(applied || job.isApplied ? Color.green : Color.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isApplying || applied || job.isApplied)

            // Open in Safari
            if let url = URL(string: job.url) {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                        Text("Open")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // ── Score breakdown ───────────────────────────────────────────────────

    private func scoreBreakdownSection(breakdown: ScoreBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 14) {

            HStack {
                Text("AI Score Breakdown")
                    .font(.headline)
                Spacer()
                Text("\(job.displayScore) / 100")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.indigo)
            }

            ForEach(breakdown.factors, id: \.name) { factor in
                HStack(spacing: 10) {
                    Text(factor.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 88, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.12))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    factor.points > 0
                                    ? LinearGradient(
                                        colors: [.indigo, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                      )
                                    : LinearGradient(
                                        colors: [Color.secondary.opacity(0.2)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                      )
                                )
                                .frame(
                                    width: factor.points > 0
                                        ? max(4, geo.size.width * CGFloat(factor.points) / 20.0)
                                        : 4
                                )
                        }
                    }
                    .frame(height: 8)

                    Text(factor.points > 0 ? "+\(factor.points)" : "–")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(factor.points > 0 ? Color.indigo : Color.secondary)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // ── Attributes ────────────────────────────────────────────────────────

    private var attributesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            VStack(spacing: 8) {
                AttributeRow(icon: "mappin.circle.fill", label: "Location",
                             value: job.location ?? "Not specified", color: .pink)
                AttributeRow(icon: "clock.fill", label: "Posted",
                             value: job.postedAgoText, color: .orange)
                AttributeRow(icon: "wifi", label: "Remote",
                             value: job.isRemote == true ? "Yes ✓" : "No", color: .green)
                AttributeRow(icon: "graduationcap.fill", label: "Experience",
                             value: job.experienceRequired ?? "Not specified", color: .blue)
                AttributeRow(icon: "airplane", label: "Visa",
                             value: job.visaSponsorship == true ? "Sponsored ✓" : "Not specified",
                             color: .purple)
                if let salary = job.salary {
                    AttributeRow(icon: "dollarsign.circle.fill", label: "Salary",
                                 value: salary, color: .green)
                }
                AttributeRow(icon: "app.badge.fill", label: "Source",
                             value: job.sourceDisplay, color: .indigo)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // ── Description (async loaded) ────────────────────────────────────────

    @ViewBuilder
    private var descriptionSection: some View {
        if isLoadingDetail {
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 12)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        // Description not shown if not available — keeps UI clean
    }

    // ── Outreach preview ──────────────────────────────────────────────────

    private func outreachPreviewSection(outreach: OutreachMessage) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Label("Outreach Ready", systemImage: "envelope.badge.fill")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Spacer()
            }

            if let recruiterName = outreach.recruiterName {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.indigo)
                        .font(.caption)
                    Text("Contact: \(recruiterName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Message preview (first 120 characters)
            if let message = outreach.message {
                Text(message.prefix(120) + (message.count > 120 ? "..." : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button {
                showOutreachSheet = true
            } label: {
                Label("View Full Message", systemImage: "envelope.open.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.indigo.opacity(0.1))
                    .foregroundStyle(.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // ── Async actions ─────────────────────────────────────────────────────

    private func loadDetail() async {
        isLoadingDetail = true

        // Fetch outreach concurrently alongside anything else
        do {
            outreach = try await APIClient.shared.fetchOutreach(jobId: job.id)
        } catch {
            // Outreach not available — just hide the section, don't show error
        }

        isLoadingDetail = false
    }

    private func markApplied() async {
        isApplying = true
        applyError = nil
        do {
            try await APIClient.shared.applyToJob(jobId: job.id, stage: "applied")
            withAnimation { applied = true }
        } catch let apiError as APIError {
            applyError = apiError.errorDescription
        } catch {
            applyError = error.localizedDescription
        }
        isApplying = false
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTREACH DETAIL SHEET
// Full-screen sheet showing the outreach message with copy + edit.
// Opened from the "View Full Message" button in JobDetailView.
// ─────────────────────────────────────────────────────────────────────────────

struct OutreachDetailSheet: View {
    let job: Job
    let outreach: OutreachMessage

    @Environment(\.dismiss) private var dismiss
    @State private var editableMessage: String
    @State private var copied = false

    init(job: Job, outreach: OutreachMessage) {
        self.job = job
        self.outreach = outreach
        _editableMessage = State(initialValue: outreach.message ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Job header ────────────────────────────────────────
                    HStack(spacing: 12) {
                        CompanyAvatar(company: job.company ?? "Unknown Company")
                        VStack(alignment: .leading, spacing: 3) {
                            Text(job.displayTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(job.company ?? "Unknown Company")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ScoreBadge(score: job.displayScore)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // ── Recruiter contact ─────────────────────────────────
                    if outreach.recruiterName != nil ||
                       outreach.recruiterEmail != nil ||
                       outreach.linkedinUrl != nil {
                        recruiterSection
                    }

                    // ── Editable message ──────────────────────────────────
                    messageSection

                    // ── Copy button ───────────────────────────────────────
                    Button {
                        UIPasteboard.general.string = editableMessage
                        withAnimation { copied = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation { copied = false }
                        }
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            Text(copied ? "Copied to clipboard!" : "Copy Message")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(copied ? Color.green : Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .animation(.easeInOut(duration: 0.2), value: copied)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Outreach Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var recruiterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recruiter Contact")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if let name = outreach.recruiterName {
                Label(name, systemImage: "person.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            if let email = outreach.recruiterEmail {
                Link(destination: URL(string: "mailto:\(email)")!) {
                    Label(email, systemImage: "envelope.fill")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            if let linkedin = outreach.linkedinUrl,
               let url = URL(string: linkedin) {
                Link(destination: url) {
                    Label("LinkedIn Profile", systemImage: "link")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Message (tap to edit)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(editableMessage.count)/300")
                    .font(.caption2)
                    .foregroundStyle(editableMessage.count > 300 ? Color.red : Color.secondary)
            }

            TextEditor(text: $editableMessage)
                .font(.subheadline)
                .frame(minHeight: 160)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

#Preview {
    NavigationStack {
        Text("JobDetailView Preview")
            .navigationTitle("Preview")
    }
}
