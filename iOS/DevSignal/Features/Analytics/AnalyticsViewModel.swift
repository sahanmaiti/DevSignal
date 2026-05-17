import Foundation
import Combine

@MainActor
final class AnalyticsViewModel: ObservableObject {

    @Published var stats: DashboardStats? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let api: any APIClientProtocol

    init(api: (any APIClientProtocol)? = nil) {
        self.api = api ?? APIClient.shared
    }

    // ── Load ──────────────────────────────────────────────────────────────

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            stats = try await api.fetchStats()
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        do {
            stats = try await api.fetchStats()
            errorMessage = nil
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // ── Derived helpers ───────────────────────────────────────────────────

    // Score distribution buckets sorted by range for the chart
    var sortedScoreBuckets: [ScoreBucket] {
        stats?.scoreDistribution.sorted {
            // Sort by the starting number in the range string e.g. "60-69" → 60
            let a = Int($0.range.components(separatedBy: "-").first ?? "0") ?? 0
            let b = Int($1.range.components(separatedBy: "-").first ?? "0") ?? 0
            return a < b
        } ?? []
    }

    // Max count across all buckets — used to scale bar heights
    var maxBucketCount: Int {
        sortedScoreBuckets.map(\.count).max() ?? 1
    }

    // Top 5 sources only — keeps the chart readable
    var topFiveSources: [SourceStat] {
        Array((stats?.topSources ?? []).prefix(5))
    }

    // Application funnel as ordered stages
    var funnelData: [(label: String, value: Int, color: String)] {
        guard let s = stats else { return [] }
        return [
            ("Total Found",   s.totalJobs,       "indigo"),
            ("Score ≥ 70",    s.jobsAbove70,     "blue"),
            ("Applied",       s.appliedCount,    "orange"),
            ("Interviewed",   s.interviewCount,  "purple"),
        ]
    }
}
