// PURPOSE:
//   Persists jobs and stats to disk using SwiftData so the app
//   remains usable when the server is unreachable.
//
// STRATEGY:
//   - On every successful API response, write to SwiftData.
//   - On API failure, read from SwiftData and show a "Cached" banner.
//   - TTL: cached data older than 24 hours is considered stale.

import Foundation
import SwiftData

// ── SwiftData model for a cached job ──────────────────────────────────────

@Model
final class CachedJob {
    @Attribute(.unique) var jobId: String
    var jsonData: Data          // full JSON blob of the Job struct
    var score: Int
    var cachedAt: Date

    init(job: Job, jsonData: Data) {
        self.jobId    = job.id
        self.jsonData = jsonData
        self.score    = job.displayScore
        self.cachedAt = Date()
    }
}

// ── SwiftData model for cached stats ──────────────────────────────────────

@Model
final class CachedStats {
    var id: String = "global"   // singleton row
    var jsonData: Data
    var cachedAt: Date

    init(jsonData: Data) {
        self.jsonData = jsonData
        self.cachedAt = Date()
    }
}

// ── Cache manager ──────────────────────────────────────────────────────────

@MainActor
final class JobCache {
    static let shared = JobCache()

    private var container: ModelContainer?
    private let ttl: TimeInterval = 24 * 60 * 60  // 24 hours

    private init() {
        do {
            let schema = Schema([CachedJob.self, CachedStats.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container  = try ModelContainer(for: schema, configurations: config)
        } catch {
            print("⚠️ JobCache: SwiftData init failed: \(error). Offline cache disabled.")
        }
    }

    // ── Write ──────────────────────────────────────────────────────────

    func save(jobs: [Job]) {
        guard let container else { return }
        let context = ModelContext(container)
        let encoder = JSONEncoder()

        for job in jobs {
            guard let data = try? encoder.encode(job) else { continue }
            // Upsert — delete existing row for this id first
            let id = job.id
            let existing = try? context.fetch(
                FetchDescriptor<CachedJob>(
                    predicate: #Predicate { $0.jobId == id }
                )
            )
            existing?.forEach { context.delete($0) }
            context.insert(CachedJob(job: job, jsonData: data))
        }

        try? context.save()
    }

    func saveStats(_ stats: DashboardStats) {
        guard let container,
              let data = try? JSONEncoder().encode(stats) else { return }
        let context = ModelContext(container)

        // Singleton row — delete and re-insert
        let existing = try? context.fetch(FetchDescriptor<CachedStats>())
        existing?.forEach { context.delete($0) }
        context.insert(CachedStats(jsonData: data))
        try? context.save()
    }

    // ── Read ───────────────────────────────────────────────────────────

    func loadJobs(minScore: Int = 0, limit: Int = 25) -> (jobs: [Job], isStale: Bool) {
        guard let container else { return ([], false) }
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<CachedJob>(
            predicate: #Predicate { $0.score >= minScore },
            sortBy: [SortDescriptor(\.score, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        guard let cached = try? context.fetch(descriptor),
              !cached.isEmpty else { return ([], false) }

        let decoder = JSONDecoder()
        let jobs = cached.compactMap { row -> Job? in
            try? decoder.decode(Job.self, from: row.jsonData)
        }

        let oldest = cached.map(\.cachedAt).min() ?? Date()
        let isStale = Date().timeIntervalSince(oldest) > ttl

        return (jobs, isStale)
    }

    func loadStats() -> (stats: DashboardStats?, isStale: Bool) {
        guard let container else { return (nil, false) }
        let context = ModelContext(container)

        guard let row = try? context.fetch(FetchDescriptor<CachedStats>()).first,
              let stats = try? JSONDecoder().decode(DashboardStats.self, from: row.jsonData)
        else { return (nil, false) }

        let isStale = Date().timeIntervalSince(row.cachedAt) > ttl
        return (stats, isStale)
    }

    // ── Purge ──────────────────────────────────────────────────────────

    func clearAll() {
        guard let container else { return }
        let context = ModelContext(container)
        try? context.delete(model: CachedJob.self)
        try? context.delete(model: CachedStats.self)
        try? context.save()
    }
}
