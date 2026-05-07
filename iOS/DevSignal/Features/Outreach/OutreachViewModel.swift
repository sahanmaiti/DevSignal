// PURPOSE:
//   Manages state for the Outreach tab.
//
// STRATEGY:
//   1. Fetch all jobs scoring ≥ 45 (these have outreach messages generated)
//   2. For each job, fetch its outreach message from /jobs/{id}/outreach
//   3. Pair them into [JobWithOutreach] for the list
//
// WHY FETCH OUTREACH INDIVIDUALLY?
//   The /jobs list endpoint doesn't include the outreach message in its
//   response (it would make the payload huge for 25+ jobs). We fetch
//   outreach lazily — only when the user opens the Outreach tab.
//
// TaskGroup:
//   Swift's way to run multiple async tasks concurrently and collect results.
//   Like asyncio.gather() in Python but with better error handling.
//   We use it to fetch all outreach messages simultaneously instead of
//   one-by-one (which would be N times slower).

import Foundation
import Combine    // ← required for @Published and ObservableObject
import UIKit      // ← required for UIPasteboard

@MainActor
final class OutreachViewModel: ObservableObject, @unchecked Sendable {

    @Published var items: [JobWithOutreach] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var copiedJobId: String? = nil   // tracks which message was just copied

    private let api = APIClient.shared
    private var hasLoaded = false

    // ── Load all outreach items ───────────────────────────────────────────

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            // Step 1: get all jobs that have outreach messages (score ≥ 45)
            let page = try await api.fetchJobsWithOutreach()
            let jobs = page.jobs

            // Step 2: fetch outreach for all jobs concurrently using TaskGroup
            // withTaskGroup creates a group of child tasks that run in parallel.
            // Each child task fetches one job's outreach message.
            // We collect results as they finish (order not guaranteed).
            var results: [JobWithOutreach] = []

            try await withThrowingTaskGroup(of: JobWithOutreach?.self) { group in
                for job in jobs {
                    // Add one child task per job
                    group.addTask {
                        do {
                            let outreach = try await self.api.fetchOutreach(jobId: job.id)
                            
                            // Inline the check instead of calling outreach.hasContent
                            // This avoids the Swift 6 actor-isolation error on computed properties
                            let hasContent = outreach.message != nil
                                          || outreach.recruiterName != nil
                                          || outreach.recruiterEmail != nil
                            
                            if hasContent {
                                return JobWithOutreach(job: job, outreach: outreach)
                            }
                            return nil
                        } catch {
                            return nil
                        }
                    }
                }

                // Collect results as each task finishes
                for try await result in group {
                    if let item = result {
                        results.append(item)
                    }
                }
            }

            // Step 3: sort by score descending (best opportunities first)
            items = results.sorted { $0.job.displayScore > $1.job.displayScore }
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
        // Avoid clearing visible data if another load is already running.
        guard !isLoading else { return }
        hasLoaded = false
        await load()
    }

    // ── Copy message to clipboard ─────────────────────────────────────────
    // Shows a brief "Copied!" indicator by setting copiedJobId,
    // then clears it after 2 seconds.

    func copyMessage(_ message: String, jobId: String) {
        UIPasteboard.general.string = message

        copiedJobId = jobId

        // Clear the "copied" indicator after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds in nanoseconds
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
