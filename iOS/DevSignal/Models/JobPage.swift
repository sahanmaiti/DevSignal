// Models/JobsPage.swift
//
// PURPOSE:
//   Represents the paginated response from GET /jobs.
//   Your FastAPI wraps job lists in an envelope:
//     { "jobs": [...], "total": 247, "page": 1, "has_more": true }
//
//   This struct decodes that envelope.

import Foundation

struct JobsPage: Codable {
    let jobs: [Job]
    let total: Int
    let page: Int
    let perPage: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case jobs, total, page
        case perPage  = "per_page"
        case hasMore  = "has_more"
    }
    
    // Convenience: a fake empty page for offline fallback
    static let empty = JobsPage(jobs: [], total: 0, page: 1, perPage: 25, hasMore: false)
}
