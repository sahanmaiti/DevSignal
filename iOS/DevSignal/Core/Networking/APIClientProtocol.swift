// PURPOSE:
//   Protocol that APIClient conforms to, allowing ViewModels to accept
//   an injected client in tests instead of always using APIClient.shared.
//
//   Production code passes nothing (uses the default = APIClient.shared).
//   Tests pass a MockAPIClient that returns canned data.

import Foundation

@MainActor
protocol APIClientProtocol {
    func fetchJobs(
        minScore:  Int,
        remote:    Bool?,
        visa:      Bool?,
        source:    String?,
        daysFresh: Int,
        page:      Int,
        perPage:   Int
    ) async throws -> JobsPage

    func fetchJob(id: String) async throws -> Job
    func fetchStats() async throws -> DashboardStats
    func fetchOutreach(jobId: String) async throws -> OutreachMessage
    func fetchOutreachBatch(jobIds: [String]) async throws -> [String: OutreachMessage]
    func fetchJobsWithOutreach(page: Int) async throws -> JobsPage
    func applyToJob(jobId: String, stage: String) async throws
    func fetchApplications() async throws -> [Application]
    func updateApplication(
        applicationId: String,
        stage: String?,
        notes: String?
    ) async throws
    func checkHealth() async -> Bool
    func runPipeline() async throws -> RunPipelineResponse
}
