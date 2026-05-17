// Manages state for the Outreach tab.
//
// STRATEGY (after PERF-4 fix):
//   1. Fetch all jobs scoring ≥ 45 — 1 HTTP request
//   2. Fetch ALL outreach messages in a single batch call — 1 HTTP request
//      (replaces the previous N concurrent individual requests)
//   3. Pair jobs with their outreach messages in memory
//
// This reduces Outreach tab load time from N+1 requests → 2 requests total.

import Foundation
import Combine
import UIKit

@MainActor
final class OutreachViewModel: ObservableObject, @unchecked Sendable {

    @Published var items: [JobWithOutreach] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var copiedJobId: String? = nil

    private let api: any APIClientProtocol

    init(api: (any APIClientProtocol)? = nil) {
        self.api = api ?? APIClient.shared
    }

    private var hasLoaded = false

    // ── Load all outreach items ───────────────────────────────────────────

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            // ── Step 1: get all jobs that have outreach messages (score ≥ 45)
            // This is 1 HTTP request that returns up to 20 job summaries.
            let page = try await api.fetchJobsWithOutreach(page: 1)
            let jobs = page.jobs

            guard !jobs.isEmpty else {
                items = []
                hasLoaded = true
                isLoading = false
                return
            }

            // ── Step 2: fetch ALL outreach messages in a single batch call.
            // Previously this fired N concurrent requests (one per job).
            // Now it fires 1 request for all jobs simultaneously.
            // The server returns [String: OutreachBatchItem] keyed by job ID.
            let jobIds: [String] = jobs.map { $0.id }
            let outreachMap: [String: OutreachMessage] = try await api.fetchOutreachBatch(
                jobIds: jobIds
            )

            // ── Step 3: pair jobs with outreach, skip jobs with no content.
            // compactMap returns nil for jobs not in outreachMap (no message generated).
            let paired: [JobWithOutreach] = jobs.compactMap { (job: Job) -> JobWithOutreach? in
                guard let outreach = outreachMap[job.id] else { return nil }
                return JobWithOutreach(job: job, outreach: outreach)
            }

            items = paired.sorted { $0.job.displayScore > $1.job.displayScore }
            hasLoaded = true

        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // ── Refresh ───────────────────────────────────────────────────────────

    func refresh() async {
        guard !isLoading else { return }
        hasLoaded = false
        await load()
    }

    // ── Copy message to clipboard ─────────────────────────────────────────
    //
    // Shows a "Copied!" indicator by setting copiedJobId,
    // then clears it after 2 seconds.

    func copyMessage(_ message: String, jobId: String) {
        UIPasteboard.general.string = message
        copiedJobId = jobId

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if copiedJobId == jobId {
                copiedJobId = nil
            }
        }
    }

    // ── Load only if not already loaded ──────────────────────────────────

    func loadIfNeeded() async {
        guard !hasLoaded && !isLoading else { return }
        await load()
    }
}
