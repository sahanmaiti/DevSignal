// Models/DashboardStats.swift
import Foundation

// Decodable only — we receive this from the API, never send it back.
// Using Decodable instead of Codable avoids requiring Encodable conformance,
// which breaks when a nested type has a custom init(from:) decoder.

struct DashboardStats: Decodable {
    let totalJobs: Int
    let avgScore: Double
    let jobsAbove70: Int
    let appliedCount: Int
    let replyRate: Double
    let interviewCount: Int
    let pipelineLastRun: String?
    let scoreDistribution: [ScoreBucket]
    let topSources: [SourceStat]

    enum CodingKeys: String, CodingKey {
        case avgScore         = "avg_score"
        case totalJobs        = "total_jobs"
        case jobsAbove70      = "jobs_above_70"
        case appliedCount     = "applied_count"
        case replyRate        = "reply_rate"
        case interviewCount   = "interview_count"
        case pipelineLastRun  = "pipeline_last_run"
        case scoreDistribution = "score_distribution"
        case topSources       = "top_sources"
    }

    var replyRatePercent: String {
        "\(Int(replyRate * 100))%"
    }

    var lastRunText: String {
        guard let pipelineLastRun,
              let date = ISO8601DateFormatter().date(from: pipelineLastRun) else {
            return "Never"
        }
        let hours = Calendar.current.dateComponents([.hour], from: date, to: Date()).hour ?? 0
        if hours < 1  { return "Just now" }
        if hours == 1 { return "1 hour ago" }
        if hours < 24 { return "\(hours) hours ago" }
        return "\(hours / 24)d ago"
    }
}

struct ScoreBucket: Decodable, Identifiable {
    let range: String
    let count: Int
    var id: String { range }
}

struct SourceStat: Decodable, Identifiable {
    let source: String
    let avgScore: Double
    let count: Int
    var id: String { source }

    enum CodingKeys: String, CodingKey {
        case source
        case jobSource = "job_source"
        case avgScore  = "avg_score"
        case count
    }

    // Custom decoder: handles both "source" (jobs table alias)
    // and "job_source" (opportunities table real column name)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        if let s = try? c.decode(String.self, forKey: .source) {
            source = s
        } else {
            source = try c.decode(String.self, forKey: .jobSource)
        }

        avgScore = try c.decode(Double.self, forKey: .avgScore)
        count    = try c.decode(Int.self,    forKey: .count)
    }
}
