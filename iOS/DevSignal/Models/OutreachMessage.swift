// PURPOSE:
//   Represents the response from GET /jobs/{id}/outreach.
//   Contains the pre-generated recruiter message and contact details.
//
// All fields are optional because:
//   - Jobs scoring < 45 have no outreach message generated
//   - Enrichment may not have found recruiter contact info
//   - We degrade gracefully: show what we have, hide what we don't

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

    // Whether this job has any outreach content worth showing
    var hasContent: Bool {
        message != nil || recruiterName != nil || recruiterEmail != nil
    }

    // Display name: use recruiter name if found, otherwise "Recruiter"
    var recruiterDisplay: String {
        recruiterName ?? "Recruiter"
    }
}

// Pairs a Job with its OutreachMessage for the Outreach tab list
// We need both because the list shows job info (title, company, score)
// AND the outreach content side by side
struct JobWithOutreach: Identifiable {
    let job: Job
    let outreach: OutreachMessage
    var id: String { job.id }
}
