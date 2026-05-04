// PURPOSE:
//   Kanban board showing all job applications grouped by stage.
//
// LAYOUT:
//   Horizontal ScrollView → one StageColumn per ApplicationStage
//   Each column → vertical list of ApplicationCard views
//   Tapping a card → ApplicationDetailSheet (move stage + add notes)
//
// NOTE: ApplicationStage enum is defined in Models/Application.swift
//   It is NOT redefined here — Swift finds it automatically in the same module.

import SwiftUI
import Combine

struct TrackerView: View {
    @StateObject private var viewModel = TrackerViewModel()
    @State private var selectedApplication: Application? = nil

    var body: some View {
        NavigationStack {
            ZStack {

                // ✅ FULL SCREEN BACKGROUND (fixed, not scrolling)
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                // ✅ CONTENT
                Group {
                    if viewModel.isLoading && viewModel.applications.isEmpty {
                        trackerSkeleton
                    } else if let error = viewModel.errorMessage,
                              viewModel.applications.isEmpty {
                        errorView(message: error)
                    } else {
                        kanbanBoard
                    }
                }
            }
            .navigationTitle("Tracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.totalCount > 0 {
                        Text("\(viewModel.totalCount) total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                if viewModel.applications.isEmpty {
                    await viewModel.load()
                }
            }
            .refreshable {
                viewModel.clearOverrides()
                await viewModel.refresh()
            }
            .sheet(item: $selectedApplication) { application in
                ApplicationDetailSheet(
                    application: application,
                    viewModel: viewModel
                )
            }
        }
    }

    // ── Kanban board ──────────────────────────────────────────────────────

    private var kanbanBoard: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(ApplicationStage.allCases) { stage in
                    StageColumn(
                        stage: stage,
                        cards: viewModel.cards(for: stage),
                        movedCardId: viewModel.movedCardId,
                        onCardTap: { application in
                            selectedApplication = application
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)      // ← add this
            .padding(.bottom, 20)  // ← add this
        }
    }

    // ── Skeleton ──────────────────────────────────────────────────────────

    private var trackerSkeleton: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(ApplicationStage.allCases) { stage in
                    StageColumnSkeleton(stage: stage)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // ── Error ─────────────────────────────────────────────────────────────

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
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGE COLUMN
// ─────────────────────────────────────────────────────────────────────────────

struct StageColumn: View {
    let stage: ApplicationStage
    let cards: [Application]
    let movedCardId: String?
    let onCardTap: (Application) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Column header ─────────────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: stage.icon)
                    .font(.caption)
                    .foregroundStyle(stage.color)
                Text(stage.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(cards.count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(stage.color.opacity(0.15))
                    .foregroundStyle(stage.color)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 24)

            Rectangle()
                .fill(stage.color.opacity(0.25))
                .frame(height: 2)
                .padding(.horizontal, 12)

            // ── Cards — NO inner ScrollView to avoid gesture conflict ──────
            // SwiftUI eats button taps when ScrollView(.vertical) is nested
            // inside ScrollView(.horizontal). Use VStack instead and let the
            // outer horizontal scroll handle overflow.
            VStack(spacing: 8) {
                if cards.isEmpty {
                    emptyColumnPlaceholder
                } else {
                    ForEach(cards) { card in
                        ApplicationCard(
                            application: card,
                            isHighlighted: movedCardId == card.applicationId,
                            onTap: { onCardTap(card) }
                        )
                    }
                }
            }
            .padding(10)
        }
        .frame(width: 190)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(minHeight: 300, alignment: .top)
    }

    private var emptyColumnPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(
                Color.secondary.opacity(0.2),
                style: StrokeStyle(lineWidth: 1.5, dash: [5])
            )
            .frame(height: 80)
            .overlay(
                Text("None")
                    .font(.caption)
                    .foregroundStyle(Color.secondary.opacity(0.5))
            )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// APPLICATION CARD
// ─────────────────────────────────────────────────────────────────────────────

struct ApplicationCard: View {
    let application: Application
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        // Use onTapGesture instead of Button to avoid ScrollView gesture conflicts
        VStack(alignment: .leading, spacing: 8) {

            HStack(alignment: .top) {
                CompanyAvatar(company: application.company)
                    .scaleEffect(0.75)
                    .frame(width: 36, height: 36)
                Spacer()
                if let score = application.score {
                    Text("\(score)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(scoreColor(score))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Text(application.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(application.company)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                if let source = application.source {
                    Text(source.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.indigo.opacity(0.1))
                        .foregroundStyle(.indigo)
                        .clipShape(Capsule())
                }
                Spacer()
                Text(application.appliedAgoText)
                    .font(.caption2)
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
        }
        .padding(10)
        .background(
            isHighlighted
                ? application.stage.color.opacity(0.15)
                : Color(.tertiarySystemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isHighlighted
                        ? application.stage.color.opacity(0.5)
                        : Color.clear,
                    lineWidth: 1.5
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
        // onTapGesture works reliably inside ScrollView unlike Button
        .onTapGesture { onTap() }
        .contentShape(Rectangle())  // makes entire card area tappable
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80:  return .indigo
        case 40..<60:  return .orange
        default:       return .gray
        }
    }
}
// ─────────────────────────────────────────────────────────────────────────────
// APPLICATION DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────

struct ApplicationDetailSheet: View {
    let application: Application
    @ObservedObject var viewModel: TrackerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var notes: String
    @State private var isSavingNotes = false
    @State private var notesSaved = false

    init(application: Application, viewModel: TrackerViewModel) {
        self.application = application
        self.viewModel = viewModel
        _notes = State(initialValue: application.notes ?? "")
    }

    // Current stage: check viewModel.cards to see if the card has been
    // optimistically moved since the sheet opened.
    private var currentStage: ApplicationStage {
        for stage in ApplicationStage.allCases {
            if viewModel.cards(for: stage).contains(where: {
                $0.applicationId == application.applicationId
            }) {
                return stage
            }
        }
        return application.stage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    jobHeader
                    stageMoverSection
                    notesSection
                    if application.appliedAt != nil {
                        metaSection
                    }
                }
                .padding(20)
            }
            .navigationTitle("Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    // ── Job header ────────────────────────────────────────────────────────

    private var jobHeader: some View {
        HStack(spacing: 14) {
            CompanyAvatar(company: application.company)
            VStack(alignment: .leading, spacing: 4) {
                Text(application.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(application.company)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let score = application.score {
                ScoreBadge(score: score)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // ── Stage mover ───────────────────────────────────────────────────────

    private var stageMoverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Move to Stage")
                .font(.headline)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(ApplicationStage.allCases) { stage in
                    StageButton(
                        stage: stage,
                        isCurrent: currentStage == stage,
                        onTap: {
                            Task {
                                await viewModel.moveCard(application, to: stage)
                                try? await Task.sleep(nanoseconds: 400_000_000)
                                dismiss()
                            }
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // ── Notes ─────────────────────────────────────────────────────────────

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                if isSavingNotes {
                    ProgressView().scaleEffect(0.8)
                } else if notesSaved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            TextEditor(text: $notes)
                .font(.subheadline)
                .frame(minHeight: 100)
                .padding(10)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                Task { await saveNotes() }
            } label: {
                Text("Save Notes")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isSavingNotes)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // ── Meta info ─────────────────────────────────────────────────────────

    private var metaSection: some View {
        HStack {
            Label("Applied \(application.appliedAgoText)", systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if let source = application.source {
                Text(source.capitalized)
                    .font(.caption)
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // ── Save notes action ─────────────────────────────────────────────────

    private func saveNotes() async {
        isSavingNotes = true
        await viewModel.saveNotes(for: application, notes: notes)
        isSavingNotes = false
        withAnimation { notesSaved = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { notesSaved = false }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

struct StageButton: View {
    let stage: ApplicationStage
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Image(systemName: stage.icon)
                    .font(.system(size: 16))
                Text(stage.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isCurrent ? stage.color : stage.color.opacity(0.1))
            .foregroundStyle(isCurrent ? Color.white : stage.color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isCurrent ? Color.clear : stage.color.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGE COLUMN SKELETON
// ─────────────────────────────────────────────────────────────────────────────

struct StageColumnSkeleton: View {
    let stage: ApplicationStage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 80, height: 12)
                Spacer()
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 24, height: 18)
            }
            .padding(12)

            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 2)
                .padding(.horizontal, 12)

            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 90)
                }
            }
            .padding(10)
        }
        .frame(width: 190)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(minHeight: 300, alignment: .top)
    }
}

#Preview {
    TrackerView()
}
