// PURPOSE:
//   Represents the response from GET /jobs/{id}/outreach.
//   Contains OutreachBatchItem for the batch endpoint response.
//
// WHY THE EXPLICIT init() METHODS:
//   Swift auto-generates a memberwise init for structs, BUT only when
//   you don't also define a custom init in the struct body.
//   We need BOTH a memberwise init (so APIClient can construct an
//   OutreachMessage from an OutreachBatchItem) AND a Decodable init
//   (so URLSession can decode the single-outreach endpoint response).
//   Defining both explicitly in the struct body satisfies the compiler.

import Foundation

struct OutreachMessage: Decodable {
    let jobId: String
    let message: String?
    let recruiterName: String?
    let recruiterEmail: String?
    let linkedinUrl: String?

    enum CodingKeys: String, CodingKey {
        case jobId         = "job_id"
        case message
        case recruiterName  = "recruiter_name"
        case recruiterEmail = "recruiter_email"
        case linkedinUrl    = "linkedin_url"
    }

    // ── Explicit memberwise init ───────────────────────────────────────────
    // Used by fetchOutreachBatch() in APIClient to construct an
    // OutreachMessage from an OutreachBatchItem.
    init(
        jobId:          String,
        message:        String?,
        recruiterName:  String?,
        recruiterEmail: String?,
        linkedinUrl:    String?
    ) {
        self.jobId          = jobId
        self.message        = message
        self.recruiterName  = recruiterName
        self.recruiterEmail = recruiterEmail
        self.linkedinUrl    = linkedinUrl
    }

    // ── Decodable init ────────────────────────────────────────────────────
    // Required because we defined a custom init above.
    // Swift only auto-generates Decodable synthesis when there is NO
    // custom init in the struct body.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        jobId          = try  c.decode(String.self,         forKey: .jobId)
        message        = try? c.decodeIfPresent(String.self, forKey: .message)
        recruiterName  = try? c.decodeIfPresent(String.self, forKey: .recruiterName)
        recruiterEmail = try? c.decodeIfPresent(String.self, forKey: .recruiterEmail)
        linkedinUrl    = try? c.decodeIfPresent(String.self, forKey: .linkedinUrl)
    }

    // ── Computed helpers ──────────────────────────────────────────────────

    // Whether this job has any outreach content worth showing
    var hasContent: Bool {
        message != nil || recruiterName != nil || recruiterEmail != nil
    }

    // Display name: use recruiter name if found, otherwise "Recruiter"
    var recruiterDisplay: String {
        recruiterName ?? "Recruiter"
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// JOB WITH OUTREACH
//
// Pairs a Job with its OutreachMessage for the Outreach tab list.
// We need both because the list shows job info (title, company, score)
// AND the outreach content side by side.
// ─────────────────────────────────────────────────────────────────────────────

struct JobWithOutreach: Identifiable {
    let job: Job
    let outreach: OutreachMessage
    var id: String { job.id }
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTREACH BATCH ITEM
//
// Shape of each VALUE in the GET /jobs/outreach?ids=1,2,3 response.
// The response is [String: OutreachBatchItem] where the key is the job ID.
// This is a separate type from OutreachMessage because the batch response
// does NOT include a job_id field (the key in the dict IS the job ID).
// ─────────────────────────────────────────────────────────────────────────────

struct OutreachBatchItem: Decodable {
    let message:        String?
    let recruiterName:  String?
    let recruiterEmail: String?
    let linkedinUrl:    String?

    enum CodingKeys: String, CodingKey {
        case message
        case recruiterName  = "recruiter_name"
        case recruiterEmail = "recruiter_email"
        case linkedinUrl    = "linkedin_url"
    }
}
