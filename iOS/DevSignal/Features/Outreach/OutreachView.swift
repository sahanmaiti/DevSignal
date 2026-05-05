// Features/Outreach/OutreachView.swift
//
// PURPOSE:
//   Shows all pre-generated recruiter outreach messages.
//   Each row shows the job + recruiter info + the message.
//   User can copy the message or tap to expand/edit it.

import SwiftUI
import Combine

struct OutreachView: View {
    @StateObject private var viewModel = OutreachViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    outreachSkeleton
                } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
                    errorView(message: error)
                } else if viewModel.items.isEmpty {
                    emptyState
                } else {
                    outreachList
                }
            }
            .navigationTitle("Outreach")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    // ── Outreach list ─────────────────────────────────────────────────────

    private var outreachList: some View {
        List {
            // Summary header
            Section {
                HStack {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundStyle(.indigo)
                    Text("\(viewModel.items.count) messages ready")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Score ≥ 45")
                        .font(.caption)
                        .foregroundStyle(.secondary)   // ← was .tertiary (wrong type)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // One card per job
            ForEach(viewModel.items) { item in
                OutreachCard(item: item, viewModel: viewModel)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // ── Skeleton loading ──────────────────────────────────────────────────

    private var outreachSkeleton: some View {
        List {
            ForEach(0..<5, id: \.self) { _ in
                OutreachSkeletonCard()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
        .allowsHitTesting(false)
    }

    // ── Empty state ───────────────────────────────────────────────────────

    private var emptyState: some View {
        ContentUnavailableView(
            "No Outreach Messages",
            systemImage: "envelope.badge",
            description: Text("Run the pipeline to score jobs. Messages are generated for jobs scoring ≥ 45.")
        )
    }

    // ── Error view ────────────────────────────────────────────────────────

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTREACH CARD
// The main card component for each job's outreach message.
// Can be expanded to show the full message and recruiter details.
// ─────────────────────────────────────────────────────────────────────────────

struct OutreachCard: View {
    let item: JobWithOutreach
    @ObservedObject var viewModel: OutreachViewModel

    @State private var isExpanded = false
    @State private var isEditing = false
    @State private var editableMessage: String

    init(item: JobWithOutreach, viewModel: OutreachViewModel) {
        self.item = item
        self.viewModel = viewModel
        _editableMessage = State(initialValue: item.outreach.message ?? "")
    }

    private var wasCopied: Bool {
        viewModel.copiedJobId == item.job.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader

            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)
                expandedContent
            }
        }
        .background(Color.dsSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }

    // ── Card header ───────────────────────────────────────────────────────

    private var cardHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                CompanyAvatar(company: item.job.company ?? "Unknown Company")

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.job.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(item.job.company ?? "Unknown Company")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let recruiterName = item.outreach.recruiterName {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundStyle(.indigo)
                            Text(recruiterName)
                                .font(.caption)
                                .foregroundStyle(.indigo)
                        }
                    }
                }

                Spacer()

                VStack(spacing: 6) {
                    ScoreBadge(score: item.job.displayScore)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.25), value: isExpanded)
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }

    // ── Expanded content ──────────────────────────────────────────────────

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if item.outreach.recruiterName != nil ||
               item.outreach.recruiterEmail != nil ||
               item.outreach.linkedinUrl != nil {
                recruiterContactStrip
            }

            if item.outreach.message != nil {
                messageSection
            }

            actionButtons
        }
        .padding(16)
    }

    // ── Recruiter contact strip ───────────────────────────────────────────

    private var recruiterContactStrip: some View {
        HStack(spacing: 12) {
            if let name = item.outreach.recruiterName {
                Label(name, systemImage: "person.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.indigo)
            }

            if let email = item.outreach.recruiterEmail {
                Link(destination: URL(string: "mailto:\(email)")!) {
                    Label(email, systemImage: "envelope.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            if let linkedinUrl = item.outreach.linkedinUrl,
               let url = URL(string: linkedinUrl) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "link").font(.caption)
                        Text("LinkedIn").font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding(10)
        .background(Color.indigo.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // ── Message section ───────────────────────────────────────────────────

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Message")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button(isEditing ? "Done" : "Edit") {
                    withAnimation { isEditing.toggle() }
                }
                .font(.caption)
                .foregroundStyle(.indigo)
            }

            if isEditing {
                TextEditor(text: $editableMessage)
                    .font(.subheadline)
                    .frame(minHeight: 120)
                    .padding(10)
                    .background(Color.dsElevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(editableMessage.count)/300")
                            .font(.caption2)
                            // FIX: both sides of ternary must be same type.
                            // Color.red and Color.secondary are both Color —
                            // .red vs .tertiary would be Color vs ShapeStyle (mismatch).
                            .foregroundStyle(
                                editableMessage.count > 300 ? Color.red : Color.secondary
                            )
                            .padding(6)
                    }
            } else {
                Text(editableMessage)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dsElevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // ── Action buttons ────────────────────────────────────────────────────

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.copyMessage(editableMessage, jobId: item.job.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: wasCopied ? "checkmark" : "doc.on.doc")
                    Text(wasCopied ? "Copied!" : "Copy Message")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(wasCopied ? Color.green : Color.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .animation(.easeInOut(duration: 0.2), value: wasCopied)
            }

            if let url = URL(string: item.job.url) {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                        Text("Apply")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.dsElevatedSurface)
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTREACH SKELETON CARD
// ─────────────────────────────────────────────────────────────────────────────

struct OutreachSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 120, height: 11)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 90, height: 10)
                }

                Spacer()

                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 40, height: 40)
            }
        }
        .padding(16)
        .background(Color.dsSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    OutreachView()
}
