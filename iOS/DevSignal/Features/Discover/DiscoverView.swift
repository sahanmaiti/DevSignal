// Features/Discover/DiscoverView.swift
//
// WHAT'S NEW vs Phase 2:
//   - @StateObject creates and owns the ViewModel
//   - .task { } calls loadJobs() when the view appears
//   - Conditional rendering: show skeleton while loading,
//     error banner on failure, real list when loaded
//   - Infinite scroll: detect when user reaches last row → load next page
//   - Pull-to-refresh with .refreshable

import SwiftUI

struct DiscoverView: View {
    
    // @StateObject: creates the ViewModel when this view is first created,
    // and keeps it alive as long as this view is alive.
    // Use @StateObject when THIS view owns the ViewModel.
    // Use @ObservedObject when the ViewModel is passed in from a parent.
    @StateObject private var viewModel = DiscoverViewModel()
    
    // Controls whether the filter sheet is showing
    @State private var showFilters = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // ── Main content ──────────────────────────────────────────
                if viewModel.isLoading && viewModel.jobs.isEmpty {
                    // First load — show skeleton
                    skeletonList
                } else if let error = viewModel.errorMessage, viewModel.jobs.isEmpty {
                    // Error with no data — show error state
                    errorView(message: error)
                } else {
                    // Data available — show real list
                    jobList
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterButton
                }
            }
            // .task runs when the view appears AND is async-aware.
            // It automatically cancels if the view disappears.
            // This is the correct way to trigger async work in SwiftUI.
            .task {
                if viewModel.jobs.isEmpty {
                    await viewModel.loadJobs()
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterSheet(viewModel: viewModel)
            }
        }
    }
    
    // ── Job list ──────────────────────────────────────────────────────────
    
    private var jobList: some View {
        List {
            // ── Error banner (if there's an error but we have cached data) ──
            if let error = viewModel.errorMessage {
                Text("⚠️ \(error)")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .listRowBackground(Color.orange.opacity(0.1))
            }
            
            // ── Job count header ──────────────────────────────────────────
            Section {
                Text("\(viewModel.totalCount) jobs found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            
            // ── Job rows ──────────────────────────────────────────────────
            ForEach(viewModel.jobs) { job in
                // NavigationLink pushes JobDetailView when a row is tapped.
                // The destination is defined as a trailing closure.
                NavigationLink(destination: JobDetailView(job: job)) {
                    JobRow(job: job)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                // ── Infinite scroll trigger ───────────────────────────────
                // When the LAST row appears on screen, load the next page.
                // .onAppear fires when a view becomes visible.
                .onAppear {
                    if job.id == viewModel.jobs.last?.id {
                        Task { await viewModel.loadNextPage() }
                    }
                }
            }
            
            // ── Pagination footer ─────────────────────────────────────────
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if !viewModel.hasMore && !viewModel.jobs.isEmpty {
                Text("All \(viewModel.totalCount) jobs loaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        // Pull-to-refresh: user pulls down → refresh() is called
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // ── Skeleton loading list ─────────────────────────────────────────────
    
    private var skeletonList: some View {
        List {
            ForEach(0..<8, id: \.self) { _ in
                DiscoverPlaceholderRow()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
        .allowsHitTesting(false)  // disable taps while loading
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
                Task { await viewModel.loadJobs() }
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
    }
    
    // ── Filter button ─────────────────────────────────────────────────────
    
    private var filterButton: some View {
        Button {
            showFilters = true
        } label: {
            // Show a filled icon when filters are active
            let isFiltered = viewModel.minScore > 0 || viewModel.remoteOnly || viewModel.visaOnly
            Image(systemName: isFiltered ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .foregroundStyle(isFiltered ? .indigo : .primary)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// JOB ROW — the card shown for each job in the list
// ─────────────────────────────────────────────────────────────────────────────

struct JobRow: View {
    let job: Job
    
    var body: some View {
        HStack(spacing: 12) {
            
            // ── Company initial avatar ────────────────────────────────────
            CompanyAvatar(company: job.company ?? "Unknown Company")
            
            // ── Job info ──────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text(job.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(job.company ?? "Unknown Company")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Pills row: Remote, Visa, Source, Posted
                HStack(spacing: 6) {
                    if job.isRemote == true {
                        PillBadge(text: "Remote", color: .green)
                    }
                    if job.visaSponsorship == true {
                        PillBadge(text: "Visa", color: .blue)
                    }
                    PillBadge(text: job.sourceDisplay, color: .indigo)
                    Text(job.postedAgoText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // ── Score badge ───────────────────────────────────────────────
            ScoreBadge(score: job.displayScore)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPORTING COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

struct CompanyAvatar: View {
    let company: String
    
    // Use the first letter of the company name as the avatar
    private var initial: String {
        String(company.prefix(1)).uppercased()
    }
    
    // Generate a consistent color from the company name
    // by hashing it to pick from a palette
    private var avatarColor: Color {
        let colors: [Color] = [.indigo, .blue, .purple, .pink, .orange, .teal, .green]
        let index = abs(company.hashValue) % colors.count
        return colors[index]
    }
    
    var body: some View {
        Text(initial)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(avatarColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PillBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER SHEET
// ─────────────────────────────────────────────────────────────────────────────

struct FilterSheet: View {
    // @ObservedObject: we don't own this ViewModel — DiscoverView does.
    // We just read and modify it.
    @ObservedObject var viewModel: DiscoverViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Local copies of the filter values — only applied when user taps "Apply"
    @State private var minScore: Double
    @State private var remoteOnly: Bool
    @State private var visaOnly: Bool
    @State private var daysFresh: Int
    
    init(viewModel: DiscoverViewModel) {
        self.viewModel = viewModel
        // Initialize local state from current ViewModel values
        _minScore   = State(initialValue: Double(viewModel.minScore))
        _remoteOnly = State(initialValue: viewModel.remoteOnly)
        _visaOnly   = State(initialValue: viewModel.visaOnly)
        _daysFresh  = State(initialValue: viewModel.daysFresh)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Minimum Score") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Score ≥ \(Int(minScore))")
                                .fontWeight(.medium)
                            Spacer()
                            ScoreBadge(score: Int(minScore))
                        }
                        // Slider: value is the bound variable, range 0...100, step 5
                        Slider(value: $minScore, in: 0...100, step: 5)
                            .tint(.indigo)
                    }
                }
                
                Section("Filters") {
                    Toggle("Remote only", isOn: $remoteOnly)
                    Toggle("Visa sponsorship", isOn: $visaOnly)
                }
                
                Section("Freshness") {
                    Picker("Posted within", selection: $daysFresh) {
                        Text("Last 7 days").tag(7)
                        Text("Last 14 days").tag(14)
                        Text("Last 30 days").tag(30)
                        Text("All time").tag(365)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        minScore   = 0
                        remoteOnly = false
                        visaOnly   = false
                        daysFresh  = 30
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        Task {
                            await viewModel.applyFilters(
                                minScore:   Int(minScore),
                                remoteOnly: remoteOnly,
                                visaOnly:   visaOnly,
                                daysFresh:  daysFresh
                            )
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])  // sheet takes up half the screen
    }
}

#Preview {
    DiscoverView()
}
