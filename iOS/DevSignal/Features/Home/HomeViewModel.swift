// Features/Home/HomeViewModel.swift
//
// PURPOSE:
//   Manages state for the Home tab.
//   Fetches stats from GET /stats and top jobs from GET /jobs.

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    
    @Published var stats: DashboardStats? = nil
    @Published var topJobs: [Job] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var isRunningPipeline = false
    @Published var pipelineStatusMessage: String? = nil
    
    private let api = APIClient.shared
    
    func load(force: Bool = false) async {
        guard !isLoading || force else { return }
        isLoading = true
        errorMessage = nil
        
        // Run both requests at the same time using async let.
        // async let starts two tasks simultaneously — faster than awaiting one by one.
        // Think of it like asyncio.gather() in Python.
        async let statsResult = api.fetchStats()
        async let jobsResult  = api.fetchJobs(minScore: 45, daysFresh: 30, perPage: 5)
        
        do {
            // Both results are awaited here — we wait for whichever finishes last
            stats   = try await statsResult
            topJobs = try await jobsResult.jobs
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func runPipelineAndWatch() async {
        guard !isRunningPipeline else { return }
        isRunningPipeline = true
        pipelineStatusMessage = nil
        errorMessage = nil

        let previousLastRun = stats?.pipelineLastRun

        do {
            let resp = try await api.runPipeline()
            pipelineStatusMessage = resp.message

            // Poll stats for completion (keep it bounded so we don't hang forever).
            // This is intentionally lightweight: if it doesn't finish soon,
            // the user can continue using the app and refresh later.
            for _ in 0..<24 { // ~2 minutes at 5s intervals
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                let latest = try await api.fetchStats()
                stats = latest
                if latest.pipelineLastRun != nil && latest.pipelineLastRun != previousLastRun {
                    pipelineStatusMessage = "Pipeline finished. Data updated."
                    break
                }
            }
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isRunningPipeline = false
    }
}
