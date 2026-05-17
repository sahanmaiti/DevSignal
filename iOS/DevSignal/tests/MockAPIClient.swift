// MockAPIClient.swift — only compile into test targets
#if DEBUG
import Foundation

@MainActor
final class MockAPIClient: APIClientProtocol {
    // Configure canned responses before calling methods
    var stubbedJobs: [Job] = []
    var stubbedStats: DashboardStats? = nil
    var shouldThrow: APIError? = nil

    func fetchJobs(minScore: Int, remote: Bool?, visa: Bool?,
                   source: String?, daysFresh: Int,
                   page: Int, perPage: Int) async throws -> JobsPage {
        if let err = shouldThrow { throw err }
        return JobsPage(jobs: stubbedJobs, total: stubbedJobs.count,
                        page: page, perPage: perPage, hasMore: false)
    }

    func fetchJob(id: String) async throws -> Job {
        if let err = shouldThrow { throw err }
        guard let job = stubbedJobs.first(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        return job
    }

    func fetchStats() async throws -> DashboardStats {
        if let err = shouldThrow { throw err }
        guard let stats = stubbedStats else { throw APIError.notFound }
        return stats
    }

    func fetchOutreach(jobId: String) async throws -> OutreachMessage {
        throw APIError.notFound
    }

    func fetchOutreachBatch(jobIds: [String]) async throws -> [String: OutreachMessage] {
        return [:]
    }

    func fetchJobsWithOutreach(page: Int) async throws -> JobsPage {
        return JobsPage(jobs: [], total: 0, page: 1, perPage: 20, hasMore: false)
    }

    func applyToJob(jobId: String, stage: String) async throws {}

    func fetchApplications() async throws -> [Application] { return [] }

    func updateApplication(applicationId: String,
                           stage: String?, notes: String?) async throws {}

    func checkHealth() async -> Bool { return true }

    func runPipeline() async throws -> RunPipelineResponse {
        return RunPipelineResponse(message: "Mock pipeline started")
    }
}
#endif
