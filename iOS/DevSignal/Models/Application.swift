// PURPOSE:
//   Represents one application record from GET /applications.
//   Each row = one job the user has marked as applied, with a stage.
//
// The `stage` field moves through:
//   applied → waiting → replied → interview → offer → rejected
//
// We keep ApplicationStage enum here (moved from TrackerView)
// so both the Model and View layers share the same type.

import Foundation
import SwiftUI

// ── ApplicationStage enum ─────────────────────────────────────────────────
// Moved here from TrackerView.swift so Application model can use it.
// TrackerView.swift will import this automatically (same module).

enum ApplicationStage: String, CaseIterable, Identifiable, Codable {
    case applied   = "applied"
    case waiting   = "waiting"
    case replied   = "replied"
    case interview = "interview"
    case offer     = "offer"
    case rejected  = "rejected"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .applied:   return "Applied"
        case .waiting:   return "Waiting"
        case .replied:   return "Replied"
        case .interview: return "Interview"
        case .offer:     return "Offer 🎉"
        case .rejected:  return "Rejected"
        }
    }

    var color: Color {
        switch self {
        case .applied:   return .indigo
        case .waiting:   return .orange
        case .replied:   return .blue
        case .interview: return .purple
        case .offer:     return .green
        case .rejected:  return .red
        }
    }

    var icon: String {
        switch self {
        case .applied:   return "paperplane.fill"
        case .waiting:   return "clock.fill"
        case .replied:   return "message.fill"
        case .interview: return "person.fill"
        case .offer:     return "star.fill"
        case .rejected:  return "xmark.circle.fill"
        }
    }

    // Next logical stage — used by quick-advance button
    var next: ApplicationStage? {
        switch self {
        case .applied:   return .waiting
        case .waiting:   return .replied
        case .replied:   return .interview
        case .interview: return .offer
        case .offer:     return nil          // terminal state
        case .rejected:  return nil          // terminal state
        }
    }
}

// ── Application model ─────────────────────────────────────────────────────

struct Application: Decodable, Identifiable, Hashable {

    let applicationId: String
    let jobId: String
    let company: String
    let title: String
    let score: Int?
    let source: String?
    let stageRaw: String
    let appliedAt: String?
    let notes: String?
    let updatedAt: String?

    var id: String { applicationId }

    var stage: ApplicationStage {
        ApplicationStage(rawValue: stageRaw) ?? .applied
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(applicationId)
    }

    static func == (lhs: Application, rhs: Application) -> Bool {
        lhs.applicationId == rhs.applicationId
    }

    var appliedAgoText: String {
        guard let appliedAt,
              let date = ISO8601DateFormatter().date(from: appliedAt) else {
            return "Recently"
        }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case 0:  return "Today"
        case 1:  return "Yesterday"
        default: return "\(days)d ago"
        }
    }

    enum CodingKeys: String, CodingKey {
        case applicationId = "application_id"
        case jobId         = "job_id"
        case company, title, score, source, notes
        case stageRaw      = "stage"
        case appliedAt     = "applied_at"
        case updatedAt     = "updated_at"
    }

    // Custom decoder: both application_id and job_id can be Int or String
    // depending on whether they come from the jobs table (Int PK)
    // or have been stringified by serialize_job. We handle both.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // application_id — UUID string from applications table, always String
        applicationId = try c.decode(String.self, forKey: .applicationId)

        // job_id — integer FK referencing opportunities.id
        if let strId = try? c.decode(String.self, forKey: .jobId) {
            jobId = strId
        } else {
            let intId = try c.decode(Int.self, forKey: .jobId)
            jobId = "\(intId)"
        }

        company   = try c.decode(String.self,  forKey: .company)
        title     = try c.decode(String.self,  forKey: .title)
        score     = try c.decodeIfPresent(Int.self,    forKey: .score)
        source    = try c.decodeIfPresent(String.self, forKey: .source)
        stageRaw  = try c.decodeIfPresent(String.self, forKey: .stageRaw) ?? "applied"
        appliedAt = try c.decodeIfPresent(String.self, forKey: .appliedAt)
        notes     = try c.decodeIfPresent(String.self, forKey: .notes)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}
extension Application {
    /// Returns a copy of this application with a different stage.
    /// Used by TrackerViewModel to update the local array without re-fetching.
    func withStage(_ newStage: ApplicationStage) -> Application {
        // We can't use a memberwise copy because Application has a custom
        // init(from:). Encode to JSON and decode back with the new stage
        // injected — this is the cleanest way to "copy with one field changed"
        // for a Decodable-only struct.
        var dict: [String: Any] = [
            "application_id": applicationId,
            "job_id":         jobId,
            "company":        company,
            "title":          title,
            "stage":          newStage.rawValue,
        ]
        if let score     { dict["score"]      = score }
        if let source    { dict["source"]     = source }
        if let appliedAt { dict["applied_at"] = appliedAt }
        if let notes     { dict["notes"]      = notes }
        if let updatedAt { dict["updated_at"] = updatedAt }

        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(Application.self, from: data)
        else {
            return self  // fallback — keep original if decode fails
        }
        return updated
    }
}
