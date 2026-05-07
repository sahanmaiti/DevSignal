// PURPOSE:
//   The Home tab. This will eventually show:
//     - A greeting header with today's date
//     - KPI summary cards (total jobs, applied, interviews)
//     - A "top picks today" feed of high-scoring jobs
//
//   For now it's a placeholder so the app compiles and runs.
//   We fill in the real content in Phase 3 when we connect to the API.
//
// NEW SWIFT CONCEPTS IN THIS FILE:
//   VStack  — arranges children vertically (like a column in CSS flexbox)
//   HStack  — arranges children horizontally (like a row)
//   Spacer  — flexible empty space that pushes other views apart
//   ScrollView — makes content scrollable
//   .padding() — adds space around a view (like CSS padding)
//   .font()    — sets text size/weight
//   .foregroundStyle() — sets text/icon color

// Features/Home/HomeView.swift — updated with real data

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @Environment(AppEnvironment.self) private var env
    @State private var showSettings = false
    @State private var showPipelineAlert = false
    @State private var isUserRefreshing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    greetingSection

                    if let error = viewModel.errorMessage {
                        Text("⚠️ \(error)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if viewModel.isLoading {
                        // Show placeholder stats while loading
                        HStack(spacing: 12) {
                            StatCard(title: "Total Jobs", value: "--", color: .indigo)
                            StatCard(title: "Applied",    value: "--", color: .green)
                            StatCard(title: "Score ≥70",  value: "--", color: .orange)
                        }
                    } else if let stats = viewModel.stats {
                        statsRow(stats: stats)
                    }

                    topJobsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle("DevSignal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            await viewModel.runPipelineAndWatch()
                            showPipelineAlert = (viewModel.pipelineStatusMessage != nil || viewModel.errorMessage != nil)
                            if viewModel.errorMessage == nil {
                                env.markDataUpdated()
                            }
                        }
                    } label: {
                        if viewModel.isRunningPipeline {
                            ProgressView()
                                .tint(.secondary)
                        } else {
                            Label("Run Pipeline", systemImage: "bolt.fill")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.indigo)
                        }
                    }
                    .disabled(viewModel.isRunningPipeline)
                    .accessibilityLabel(viewModel.isRunningPipeline ? "Pipeline running" : "Run pipeline")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task(id: env.dataVersion) {
                guard !isUserRefreshing else { return }
                await viewModel.load()
            }
            .refreshable {
                isUserRefreshing = true
                defer { isUserRefreshing = false }

                await viewModel.load(force: true)
            }
            .alert("Pipeline", isPresented: $showPipelineAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                } else {
                    Text(viewModel.pipelineStatusMessage ?? "Pipeline started.")
                }
            }
        }
    }

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.title2)
                .fontWeight(.semibold)

            if let stats = viewModel.stats {
                Text("Pipeline ran \(stats.lastRunText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if viewModel.isRunningPipeline {
                    Text("Running pipeline…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Your iOS job radar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statsRow(stats: DashboardStats) -> some View {
        HStack(spacing: 12) {
            StatCard(title: "Total Jobs", value: "\(stats.totalJobs)",    color: .indigo)
            StatCard(title: "Applied",    value: "\(stats.appliedCount)", color: .green)
            StatCard(title: "Score ≥70",  value: "\(stats.jobsAbove70)", color: .orange)
        }
    }

    private var topJobsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Picks Today")
                    .font(.headline)
                Spacer()
                NavigationLink("See all") {
                    DiscoverView()
                }
                .font(.subheadline)
                .foregroundStyle(.indigo)
            }

            if viewModel.isLoading {
                ForEach(0..<3, id: \.self) { _ in PlaceholderJobCard() }
            } else if viewModel.topJobs.isEmpty {
                ContentUnavailableView(
                    "No top jobs yet",
                    systemImage: "magnifyingglass",
                    description: Text("Run the pipeline to discover iOS opportunities.")
                )
                .frame(height: 150)
            } else {
                ForEach(viewModel.topJobs) { job in
                    NavigationLink(destination: JobDetailView(job: job)) {
                        JobRow(job: job)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning 👋"
        case 12..<17: return "Good afternoon 👋"
        default: return "Good evening 👋"
        }
    }
}

#Preview {
    HomeView()
}
