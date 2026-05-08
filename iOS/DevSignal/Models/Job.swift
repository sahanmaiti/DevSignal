// PURPOSE:
//   The Swift representation of a job returned by GET /jobs and GET /jobs/{id}.
//   Every property name matches the JSON key your FastAPI returns exactly.
//
// CODABLE:
//   Adding ": Codable" to a struct means Swift can automatically:
//     - Decode JSON → Job  (when you receive data from the API)
//     - Encode Job → JSON  (if you ever need to send one back)
//
// IDENTIFIABLE:
//   Adding ": Identifiable" means SwiftUI's ForEach can use this type
//   directly. It requires an `id` property — which we already have.
//
// OPTIONAL PROPERTIES (marked with ?):
//   Some fields may be null in the JSON (e.g. visa_sponsorship might not
//   be known for every job). We mark those as optional with ?.
//   Swift will set them to nil if the JSON has null or the key is missing.
//
// CodingKeys:
//   Your API returns snake_case keys (is_remote, posted_at).
//   Swift conventionally uses camelCase (isRemote, postedAt).
//   CodingKeys is an enum that maps between the two.

import Foundation

struct Job: Codable, Identifiable {
    
    // id is stored as Int in Postgres but we keep it as String in Swift
    // so all URL building (  /jobs/\(job.id)  ) works without changes.
    // The custom init below handles the conversion transparently.
    
    // ── Core fields ───────────────────────────────────────────────────────
    let id: String
    let title: String?
    let company: String?
    let source: String
    let url: String
    
    // ── AI Score ──────────────────────────────────────────────────────────
    let score: Int?
    let scoreBreakdown: ScoreBreakdown?
    let scoreExplanation: String?
    
    // ── Job attributes ────────────────────────────────────────────────────
    let isRemote: Bool?
    let visaSponsorship: Bool?
    let isIosProduct: Bool?
    let experienceRequired: String?
    let location: String?
    let salary: String?
    
    // ── Timestamps ────────────────────────────────────────────────────────
    let postedAt: String?     // ISO 8601 string — we parse it when needed
    let discoveredAt: String?
    
    // ── Application tracking ──────────────────────────────────────────────
    let applicationStatus: String?
    
    // ── CodingKeys: maps Swift camelCase → JSON snake_case ────────────────
    // Every property that differs between Swift name and JSON key needs
    // an entry here. Properties with the same name (id, title, company,
    // source, url, score, location, salary) don't need one.
    enum CodingKeys: String, CodingKey {
        case id, title, company, source, url
        case score, location, salary
        case scoreBreakdown     = "score_breakdown"
        case scoreExplanation   = "score_explanation"
        case isRemote           = "is_remote"
        case visaSponsorship    = "visa_sponsorship"
        case isIosProduct       = "is_ios_product"
        case experienceRequired = "experience_required"
        case postedAt           = "posted_at"
        case discoveredAt       = "discovered_at"
        case applicationStatus  = "application_status"
        }
    
    // Custom decoder: id can be either Int or String in the JSON.
        // Postgres integer primary keys come back as JSON numbers.
        // We convert to String here so every other part of the app
        // treats id as a String — no changes needed anywhere else.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // id: handle both Int and String from DB
        if let stringId = try? c.decode(String.self, forKey: .id) {
            id = stringId
        } else {
            let intId = try c.decode(Int.self, forKey: .id)
            id = "\(intId)"
        }

        title   = try c.decode(String.self, forKey: .title)
        company = try c.decode(String.self, forKey: .company)
        source  = try c.decode(String.self, forKey: .source)
        url     = try c.decode(String.self, forKey: .url)

        score             = try c.decodeIfPresent(Int.self,            forKey: .score)
        scoreBreakdown    = try c.decodeIfPresent(ScoreBreakdown.self, forKey: .scoreBreakdown)
        scoreExplanation  = try c.decodeIfPresent(String.self,         forKey: .scoreExplanation)
        experienceRequired = try c.decodeIfPresent(String.self,        forKey: .experienceRequired)
        location          = try c.decodeIfPresent(String.self,         forKey: .location)
        salary            = try c.decodeIfPresent(String.self,         forKey: .salary)
        postedAt          = try c.decodeIfPresent(String.self,         forKey: .postedAt)
        discoveredAt      = try c.decodeIfPresent(String.self,         forKey: .discoveredAt)
        applicationStatus = try c.decodeIfPresent(String.self,         forKey: .applicationStatus)
        isIosProduct      = try c.decodeIfPresent(Bool.self,           forKey: .isIosProduct)

        // is_remote and visa_sponsorship are stored as "Yes"/"No"/"Unknown" strings
        // in the opportunities table. We try Bool first (future-proof for the jobs
        // table which may store real booleans), then fall back to string parsing.
        isRemote = Self.decodeBoolOrString(c, forKey: .isRemote)
        visaSponsorship = Self.decodeBoolOrString(c, forKey: .visaSponsorship)
    }

    // Helper: tries Bool first, then interprets "Yes"/"yes"/"true"/"1" as true
    private static func decodeBoolOrString(
        _ c: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Bool? {
        // Try native Bool first
        if let b = try? c.decodeIfPresent(Bool.self, forKey: key) {
            return b
        }
        // Fall back to string interpretation
        if let s = try? c.decodeIfPresent(String.self, forKey: key) {
            switch s.lowercased() {
            case "yes", "true", "1": return true
            case "no", "false", "0", "unknown": return false
            default: return nil
            }
        }
        return nil
    }
    
    // ── Computed helpers (not from JSON — derived in Swift) ───────────────
    
    // Safe score with fallback to 0
    var displayScore: Int { score ?? 0 }
    
    // Short source name for display
    var sourceDisplay: String {
        switch source {
        case "remoteok":       return "RemoteOK"
        case "hackernews":     return "HN"
        case "yc":             return "YC"
        case "remotive":       return "Remotive"
        case "himalayas":      return "Himalayas"
        case "weworkremotely": return "WWR"
        case "wellfound":      return "Wellfound"
        default:               return source.capitalized
        }
    }
    
    // Human-readable "posted X days ago" string
    var postedAgoText: String {
        guard let postedAt,
              let date = ISO8601DateFormatter().date(from: postedAt) else {
            return "Unknown date"
        }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case 0:  return "Today"
        case 1:  return "Yesterday"
        default: return "\(days)d ago"
        }
    }

    // Normalized title for UI. Falls back to parsing the URL when APIs send placeholders.
    var displayTitle: String {
        if let title {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = trimmed.lowercased()
            if !trimmed.isEmpty && normalized != "untitled job" && normalized != "untitled" {
                return trimmed
            }
        }

        if let derived = deriveTitleFromURL() {
            return derived
        }

        return "Role"
    }
    
    // Whether this job has been applied to
    var isApplied: Bool {
        applicationStatus != nil && applicationStatus != ""
    }

    private func deriveTitleFromURL() -> String? {
        guard let parsedURL = URL(string: url) else { return nil }
        let rawSlug = parsedURL.lastPathComponent
        guard !rawSlug.isEmpty else { return nil }

        var pieces = rawSlug.split(separator: "-").map(String.init)
        guard !pieces.isEmpty else { return nil }

        // Remove likely opaque trailing token.
        if let last = pieces.last,
           last.count >= 7,
           last.range(of: "^[A-Za-z0-9]+$", options: .regularExpression) != nil {
            pieces.removeLast()
        }

        // Remove company prefix if the slug starts with company words.
        if let company {
            let companyTokens = company
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)

            var matchCount = 0
            while matchCount < companyTokens.count &&
                    matchCount < pieces.count &&
                    pieces[matchCount].lowercased() == companyTokens[matchCount] {
                matchCount += 1
            }
            if matchCount > 0 && matchCount < pieces.count {
                pieces.removeFirst(matchCount)
            }
        }

        let candidate = pieces.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }
        return candidate.capitalized
    }
}

// ── ScoreBreakdown ────────────────────────────────────────────────────────
// Matches the score_breakdown JSON produced by run_scorer.py

// Replace the entire ScoreBreakdown struct at the bottom of Job.swift

struct ScoreBreakdown: Codable {
    let iosRelevance:    Int?
    let remote:          Int?
    let experienceMatch: Int?
    let productQuality:  Int?
    let salary:          Int?
    let visa:            Int?

    enum CodingKeys: String, CodingKey {
        case iosRelevance    = "ios_relevance"
        case remote          = "remote"
        case experienceMatch = "experience_match"
        case productQuality  = "product_quality"
        case salary          = "salary"
        case visa            = "visa"
    }

    // Max possible points per factor (matches run_scorer.py VALID_VALUES)
    private static let maxPoints: [String: Int] = [
        "iOS Relevance": 30,
        "Remote":        20,
        "Experience":    20,
        "Product":       15,
        "Salary":        10,
        "Visa":           5,
    ]

    var factors: [(name: String, points: Int, maxPoints: Int)] {
        [
            ("iOS Relevance", iosRelevance    ?? 0, 30),
            ("Remote",        remote          ?? 0, 20),
            ("Experience",    experienceMatch ?? 0, 20),
            ("Product",       productQuality  ?? 0, 15),
            ("Salary",        salary          ?? 0, 10),
            ("Visa",          visa            ?? 0,  5),
        ]
    }
}
