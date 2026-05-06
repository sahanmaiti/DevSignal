import SwiftUI
import Charts
import Combine

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dsBackground.ignoresSafeArea()

                if viewModel.isLoading && viewModel.stats == nil {
                    loadingView
                } else if let error = viewModel.errorMessage,
                          viewModel.stats == nil {
                    errorView(message: error)
                } else {
                    analyticsContent
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if viewModel.stats == nil { await viewModel.load() }
            }
            .refreshable {
                await viewModel.refresh()
                if viewModel.errorMessage == nil {
                    env.markDataUpdated()
                }
            }
        }
    }

    // ── Main content ──────────────────────────────────────────────────────

    private var analyticsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                pipelineHealthSection
                kpiCardsSection
                scoreDistributionSection
                funnelSection
                topSourcesSection
                lastRunSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // ── Pipeline health ───────────────────────────────────────────────────

    private var pipelineHealthSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Pipeline Health", systemImage: "bolt.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            if let stats = viewModel.stats {
                Text("Last run: \(stats.lastRunText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    // ── KPI cards ─────────────────────────────────────────────────────────

    private var kpiCardsSection: some View {
        let stats = viewModel.stats

        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            KPICard(
                title: "Total Jobs",
                value: "\(stats?.totalJobs ?? 0)",
                icon: "briefcase.fill",
                color: .indigo
            )
            KPICard(
                title: "Avg Score",
                value: String(format: "%.1f", Double(stats?.avgScore ?? 0)),
                icon: "star.fill",
                color: .orange
            )
            KPICard(
                title: "Score ≥ 70",
                value: "\(stats?.jobsAbove70 ?? 0)",
                icon: "chart.bar.fill",
                color: .blue
            )
            KPICard(
                title: "Reply Rate",
                value: stats?.replyRatePercent ?? "0%",
                icon: "envelope.fill",
                color: .green
            )
        }
    }

    // ── Score distribution chart ──────────────────────────────────────────

    private var scoreDistributionSection: some View {
        SectionCard(title: "Score Distribution", icon: "chart.bar.xaxis") {
            if viewModel.sortedScoreBuckets.isEmpty {
                emptyChartPlaceholder(message: "No scored jobs yet")
            } else {
                Chart(viewModel.sortedScoreBuckets) { bucket in
                    BarMark(
                        x: .value("Range", bucket.range),
                        y: .value("Jobs", bucket.count)
                    )
                    .foregroundStyle(
                        // Color bars by score range
                        barColor(for: bucket.range).gradient
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .font(.system(size: 10))
                        AxisGridLine()
                    }
                }
                .frame(height: 180)
            }
        }
    }

    // ── Application funnel ────────────────────────────────────────────────

    private var funnelSection: some View {
        SectionCard(title: "Application Funnel", icon: "line.diagonal.arrow") {
            VStack(spacing: 10) {
                ForEach(viewModel.funnelData, id: \.label) { item in
                    FunnelRow(
                        label: item.label,
                        value: item.value,
                        maxValue: viewModel.funnelData.map(\.value).max() ?? 1,
                        colorName: item.color
                    )
                }
            }
        }
    }

    // ── Top sources ───────────────────────────────────────────────────────

    private var topSourcesSection: some View {
        SectionCard(title: "Top Sources by Score", icon: "globe") {
            if viewModel.topFiveSources.isEmpty {
                emptyChartPlaceholder(message: "No source data yet")
            } else {
                VStack(spacing: 0) {
                    // Header row
                    HStack {
                        Text("Source")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Avg Score")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Jobs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .padding(.bottom, 8)

                    Divider()

                    ForEach(viewModel.topFiveSources) { source in
                        SourceRow(source: source)
                        if source.id != viewModel.topFiveSources.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // ── Last run info ─────────────────────────────────────────────────────

    private var lastRunSection: some View {
        SectionCard(title: "Pipeline Status", icon: "gearshape.2.fill") {
            HStack(spacing: 16) {
                StatusIndicator(
                    label: "Last Run",
                    value: viewModel.stats?.lastRunText ?? "Never",
                    icon: "clock.fill",
                    color: .indigo
                )
                Divider().frame(height: 40)
                StatusIndicator(
                    label: "Total Jobs",
                    value: "\(viewModel.stats?.totalJobs ?? 0)",
                    icon: "tray.fill",
                    color: .blue
                )
                Divider().frame(height: 40)
                StatusIndicator(
                    label: "Applied",
                    value: "\(viewModel.stats?.appliedCount ?? 0)",
                    icon: "paperplane.fill",
                    color: .green
                )
            }
        }
    }

    // ── Loading / Error / Empty ───────────────────────────────────────────

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("Loading analytics…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
    }

    private func emptyChartPlaceholder(message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private func barColor(for range: String) -> Color {
        let start = Int(range.components(separatedBy: "-").first ?? "0") ?? 0
        switch start {
        case 80...: return .green
        case 60..<80: return .indigo
        case 40..<60: return .orange
        default: return .red
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPORTING COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

// Reusable card container with title + icon header
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding(16)
        .background(Color.dsGroupedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// KPI metric card
struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color)
                }
                Spacer()
            }

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.easeInOut, value: value)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.dsGroupedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// Horizontal funnel bar row
struct FunnelRow: View {
    let label: String
    let value: Int
    let maxValue: Int
    let colorName: String

    private var barColor: Color {
        switch colorName {
        case "indigo": return .indigo
        case "blue":   return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "green":  return .green
        default:       return .indigo
        }
    }

    private var fraction: CGFloat {
        maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) : 0
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.1))

                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [barColor, barColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * fraction))
                        .animation(.spring(duration: 0.6), value: fraction)
                }
            }
            .frame(height: 10)

            Text("\(value)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(barColor)
                .frame(width: 40, alignment: .trailing)
                .contentTransition(.numericText())
        }
    }
}

// Source performance row in the top sources table
struct SourceRow: View {
    let source: SourceStat

    private var scoreColor: Color {
        switch source.avgScore {
        case 70...: return .green
        case 50..<70: return .indigo
        default: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Source name with coloured dot
            Circle()
                .fill(scoreColor)
                .frame(width: 7, height: 7)

            Text(displayName)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            // Average score pill
            Text(String(format: "%.1f", source.avgScore))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor)
                .frame(width: 40, alignment: .center)

            // Job count
            Text("\(source.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }

    private var displayName: String {
        switch source.source {
        case "remoteok":       return "RemoteOK"
        case "hackernews":     return "HackerNews"
        case "yc":             return "YC Startups"
        case "remotive":       return "Remotive"
        case "himalayas":      return "Himalayas"
        case "weworkremotely": return "WeWorkRemotely"
        case "wellfound":      return "Wellfound"
        case "startupjobs":    return "Startup.jobs"
        case "cutshort":       return "Cutshort"
        case "naukri":         return "Naukri"
        default: return source.source.capitalized
        }
    }
}

// Pipeline status indicator (used in last run section)
struct StatusIndicator: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AnalyticsView()
}
