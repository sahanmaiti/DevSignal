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
    
    private let api = APIClient.shared
    
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        
        // Run both requests at the same time using async let.
        // async let starts two tasks simultaneously — faster than awaiting one by one.
        // Think of it like asyncio.gather() in Python.
        async let statsResult = api.fetchStats()
        async let jobsResult  = api.fetchJobs(minScore: 60, daysFresh: 7, perPage: 5)
        
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
}
