// Features/Tracker/TrackerView.swift
//
// Premium Kanban board for the DevSignal iOS app.
// Designed for App Store release — full-height columns, clean cards,
// smooth stage-move interactions.

import SwiftUI
import Combine

struct TrackerView: View {
    @StateObject private var viewModel = TrackerViewModel()
    @Environment(AppEnvironment.self) private var env
    @State private var selectedApplication: Application? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle gradient background
                LinearGradient(
                    colors: [Color.dsBackground, Color.dsPlainBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if viewModel.isLoading && viewModel.applications.isEmpty {
                    loadingView
                } else if let error = viewModel.errorMessage,
                          viewModel.applications.isEmpty {
                    errorView(message: error)
                } else {
                    kanbanBoard
                }
            }
            .navigationTitle("Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text("Tracker")
                            .font(.headline)
                            .fontWeight(.semibold)
                        if viewModel.totalCount > 0 {
                            Text("\(viewModel.totalCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.indigo.opacity(0.15))
                                .foregroundStyle(.indigo)
                                .clipShape(Capsule())
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            viewModel.clearOverrides()
                            await viewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task(id: env.dataVersion) {
                await viewModel.refresh()
            }
            .sheet(item: $selectedApplication) { app in
                ApplicationDetailSheet(application: app, viewModel: viewModel)
            }
        }
    }

    // ── Kanban board ──────────────────────────────────────────────────────
    // GeometryReader measures the available height so each column can fill
    // it exactly — this prevents the "floating small box" problem.

    private var kanbanBoard: some View {
        GeometryReader { geo in
            // Guard against NaN, infinity, AND zero/negative during first layout pass.
            let rawHeight = geo.size.height - 24
            let columnHeight: CGFloat = (rawHeight.isFinite && rawHeight > 0) ? rawHeight : 400

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(ApplicationStage.allCases) { stage in
                        StageColumn(
                            stage: stage,
                            cards: viewModel.cards(for: stage),
                            movedCardId: viewModel.movedCardId,
                            availableHeight: columnHeight,
                            onCardTap: { selectedApplication = $0 }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
    // ── Loading ───────────────────────────────────────────────────────────

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading applications…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // ── Error ─────────────────────────────────────────────────────────────

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try Again") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGE COLUMN
// Full-height column — background extends from top to bottom of the board.
// availableHeight is passed in from GeometryReader so every column is
// exactly the same height regardless of card count.
// ─────────────────────────────────────────────────────────────────────────────

struct StageColumn: View {
    let stage: ApplicationStage
    let cards: [Application]
    let movedCardId: String?
    let availableHeight: CGFloat
    let onCardTap: (Application) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            columnHeader
            colorBar
            cardStack
            Spacer(minLength: 0)
        }
        .frame(width: 200, height: availableHeight)
        .background(columnBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.dsMuted.opacity(0.22), radius: 8, x: 0, y: 2)
    }

    // ── Header ────────────────────────────────────────────────────────────

    private var columnHeader: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(stage.color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: stage.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(stage.color)
            }

            Text(stage.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Spacer()

            if !cards.isEmpty {
                Text("\(cards.count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(stage.color)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var colorBar: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [stage.color.opacity(0.6), stage.color.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .padding(.horizontal, 14)
    }

    // ── Card stack ────────────────────────────────────────────────────────

    private var cardStack: some View {
        VStack(spacing: 8) {
            if cards.isEmpty {
                emptyPlaceholder
            } else {
                ForEach(cards) { card in
                    ApplicationCard(
                        application: card,
                        stage: stage,
                        isHighlighted: movedCardId == card.applicationId,
                        onTap: { onCardTap(card) }
                    )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: stage.icon)
                .font(.system(size: 22))
                .foregroundStyle(stage.color.opacity(0.25))
            Text("None yet")
                .font(.caption)
                .foregroundStyle(Color.secondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [5])
                )
                .foregroundStyle(Color.secondary.opacity(0.2))
        )
    }

    private var columnBackground: some View {
        ZStack {
            // Base fill
            Color.dsGroupedSurface
            // Subtle top tint from stage colour
            LinearGradient(
                colors: [stage.color.opacity(0.04), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// APPLICATION CARD
// Premium card design with company avatar, score pill, and metadata.
// Uses .onTapGesture instead of Button to avoid ScrollView gesture conflicts.
// ─────────────────────────────────────────────────────────────────────────────

struct ApplicationCard: View {
    let application: Application
    let stage: ApplicationStage
    let isHighlighted: Bool
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Top row: avatar + score ───────────────────────────────────
            HStack(alignment: .top, spacing: 0) {
                // Company initial
                Text(String(application.company.prefix(1)).uppercased())
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(avatarColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                if let score = application.score {
                    Text("\(score)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(scorePillColor(score))
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 8)

            // ── Title ─────────────────────────────────────────────────────
            Text(application.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 3)

            // ── Company ───────────────────────────────────────────────────
            Text(application.company)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.bottom, 8)

            // ── Footer ────────────────────────────────────────────────────
            HStack(spacing: 0) {
                if let source = application.source {
                    Text(source.capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.indigo.opacity(0.1))
                        .foregroundStyle(.indigo)
                        .clipShape(Capsule())
                }
                Spacer()
                Text(application.appliedAgoText)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary.opacity(0.7))
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(highlightBorder)
        .scaleEffect(pressed ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: pressed)
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        ._onButtonGesture(pressing: { pressing in
            withAnimation { pressed = pressing }
        }, perform: {})
    }

    private var cardBackground: some View {
        ZStack {
            Color.dsElevatedGroupedSurface
            if isHighlighted {
                stage.color.opacity(0.08)
            }
        }
    }

    private var highlightBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(
                isHighlighted ? stage.color.opacity(0.4) : Color.clear,
                lineWidth: 1.5
            )
    }

    private var avatarColor: Color {
        let colors: [Color] = [.indigo, .blue, .purple, .pink, .orange, .teal, .green]
        let index = abs(application.company.hashValue) % colors.count
        return colors[index]
    }

    private func scorePillColor(_ score: Int) -> Color {
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
    @State private var isSaving = false
    @State private var saved = false

    init(application: Application, viewModel: TrackerViewModel) {
        self.application = application
        self.viewModel = viewModel
        _notes = State(initialValue: application.notes ?? "")
    }

    private var currentStage: ApplicationStage {
        for stage in ApplicationStage.allCases {
            if viewModel.cards(for: stage).contains(where: {
                $0.applicationId == application.applicationId
            }) { return stage }
        }
        return application.stage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    jobHeader
                    stageMover
                    notesSection
                    metaRow
                }
                .padding(20)
            }
            .background(Color.dsBackground.ignoresSafeArea())
            .navigationTitle("Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.indigo)
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
    }

    // ── Job header ────────────────────────────────────────────────────────

    private var jobHeader: some View {
        HStack(spacing: 14) {
            // Large company avatar
            Text(String(application.company.prefix(1)).uppercased())
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(
                    LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

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
        .background(Color.dsGroupedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // ── Stage mover ───────────────────────────────────────────────────────

    private var stageMover: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Move to Stage")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                spacing: 10
            ) {
                ForEach(ApplicationStage.allCases) { stage in
                    stageButton(stage)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .background(Color.dsGroupedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func stageButton(_ stage: ApplicationStage) -> some View {
        let isCurrent = currentStage == stage

        return Button {
            Task {
                await viewModel.moveCard(application, to: stage)
                try? await Task.sleep(nanoseconds: 300_000_000)
                dismiss()
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isCurrent ? stage.color : stage.color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: stage.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isCurrent ? .white : stage.color)
                }

                Text(stage.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isCurrent ? stage.color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrent ? stage.color.opacity(0.1) : Color.dsElevatedGroupedSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isCurrent ? stage.color.opacity(0.4) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // ── Notes ─────────────────────────────────────────────────────────────

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                if isSaving {
                    ProgressView().scaleEffect(0.75)
                } else if saved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }

            TextEditor(text: $notes)
                .font(.subheadline)
                .frame(minHeight: 90)
                .padding(10)
                .background(Color.dsElevatedGroupedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
                )

            Button {
                Task { await doSaveNotes() }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Text("Save Notes")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isSaving)
        }
        .padding(16)
        .background(Color.dsGroupedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // ── Meta row ──────────────────────────────────────────────────────────

    private var metaRow: some View {
        HStack {
            Label(application.appliedAgoText, systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if let source = application.source {
                Text(source.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.1))
                    .foregroundStyle(.indigo)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.dsGroupedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // ── Actions ───────────────────────────────────────────────────────────

    private func doSaveNotes() async {
        isSaving = true
        await viewModel.saveNotes(for: application, notes: notes)
        isSaving = false
        withAnimation { saved = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { saved = false }
        }
    }
}

#Preview {
    TrackerView()
}
