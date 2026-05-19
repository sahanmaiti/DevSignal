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
    
    private let api: any APIClientProtocol
    
    init(api: (any APIClientProtocol)? = nil) {
        self.api = api ?? APIClient.shared
    }
    
    func load(force: Bool = false) async {
        guard !isLoading || force else { return }
        isLoading = true
        errorMessage = nil

        do {
            async let statsResult = api.fetchStats()
            async let jobsResult  = api.fetchJobs(
                minScore: 45, remote: nil, visa: nil,
                source: nil, daysFresh: 30, page: 1, perPage: 5
            )
            stats   = try await statsResult
            topJobs = try await jobsResult.jobs

            if let stats { JobCache.shared.saveStats(stats) }
            JobCache.shared.save(jobs: topJobs)

        } catch APIError.rateLimited {
            // Stats are rate limited — silently serve cache, don't show error
            let (cachedStats, _) = JobCache.shared.loadStats()
            let (cachedJobs, _)  = JobCache.shared.loadJobs(minScore: 45, limit: 5)
            stats   = cachedStats
            topJobs = cachedJobs
            // Only show error if we have nothing at all to show
            if cachedStats == nil {
                errorMessage = "Too many requests — please wait a moment."
            }

        } catch APIError.networkUnavailable {
            let (cachedStats, _) = JobCache.shared.loadStats()
            let (cachedJobs, _)  = JobCache.shared.loadJobs(minScore: 45, limit: 5)
            stats   = cachedStats
            topJobs = cachedJobs
            if cachedStats == nil {
                errorMessage = "No internet connection."
            }

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
            
            for _ in 0..<24 {
                try await Task.sleep(nanoseconds: 5_000_000_000) // cancellable
                let latest = try await api.fetchStats()
                stats = latest
                if latest.pipelineLastRun != nil,
                   latest.pipelineLastRun != previousLastRun {
                    pipelineStatusMessage = "Pipeline finished. Data updated."
                    break
                }
            }
            
        } catch APIError.rateLimited {
            // Not a real error — just inform and auto-clear after 4 seconds
            errorMessage = "Pipeline ran recently — please wait a few minutes."
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if errorMessage?.contains("Pipeline ran recently") == true {
                    errorMessage = nil
                }
            }
            
        } catch is CancellationError {
            // Task was cancelled (user navigated away) — clean up silently
            
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isRunningPipeline = false
    }
}
