// All methods are inside the APIClient final class.
// fetchOutreachBatch is added after fetchOutreach — both use the
// private fetch() helper, which is only visible inside this class.

import Foundation

@MainActor
final class APIClient: APIClientProtocol {

    static let shared = APIClient()
    private init() {}

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // ─────────────────────────────────────────────────────────────────────
    // PRIVATE HELPER: build a URLRequest with auth header
    // ─────────────────────────────────────────────────────────────────────

    private func makeRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) throws -> URLRequest {

        let base = AppEnvironment.shared.baseURL
        let key  = AppEnvironment.shared.currentAPIKey()

        guard var urlComponents = URLComponents(string: base + path) else {
            throw APIError.invalidURL
        }

        if method == "GET" {
            var items = urlComponents.queryItems ?? []
            items.append(URLQueryItem(
                name:  "_ts",
                value: "\(Int(Date().timeIntervalSince1970 * 1000))"
            ))
            urlComponents.queryItems = items
        }

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(key,                forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache",         forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 15

        if let body {
            request.httpBody = body
        }

        return request
    }

    // ─────────────────────────────────────────────────────────────────────
    // PRIVATE HELPER: execute a request and decode the response
    // ─────────────────────────────────────────────────────────────────────

    /// Decodes a JSON array, silently skipping any elements that fail to decode.
    /// Used for list endpoints where one bad record shouldn't blank the page.
    private func fetchArray<T: Decodable>(
        path: String,
        method: String = "GET"
    ) async throws -> [T] {
        let request = try makeRequest(path: path, method: method)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw APIError.cancelled
        } catch let urlError as URLError {
            if urlError.code == .notConnectedToInternet ||
               urlError.code == .networkConnectionLost {
                throw APIError.networkUnavailable
            }
            throw APIError.unknown(urlError.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown("Invalid response type")
        }
        switch httpResponse.statusCode {
        case 200...299: break
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        case 429: throw APIError.rateLimited
        case 500...599: throw APIError.serverError(httpResponse.statusCode)
        default: throw APIError.unknown("HTTP \(httpResponse.statusCode)")
        }

        // Decode as raw JSON array first
        guard let rawArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            // Not a JSON array — fall back to normal decode (e.g. wrapped response)
            return (try? decoder.decode([T].self, from: data)) ?? []
        }

        // Decode each element individually, skipping failures
        var results: [T] = []
        var skipped = 0
        for element in rawArray {
            if let elementData = try? JSONSerialization.data(withJSONObject: element),
               let decoded = try? decoder.decode(T.self, from: elementData) {
                results.append(decoded)
            } else {
                skipped += 1
            }
        }
        if skipped > 0 {
            print("⚠️ APIClient: skipped \(skipped) malformed \(T.self) records")
        }
        return results
    }
    
    private func fetch<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {

        let request = try makeRequest(path: path, method: method, body: body)

        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw APIError.cancelled
        } catch let urlError as URLError {
            if urlError.code == .notConnectedToInternet ||
               urlError.code == .networkConnectionLost {
                throw APIError.networkUnavailable
            }
            if urlError.code == .cancelled {
                throw APIError.cancelled
            }
            throw APIError.unknown(urlError.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown("Invalid response type")
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimited
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.unknown("HTTP \(httpResponse.statusCode)")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            print("❌ Decoding error for \(T.self): \(decodingError)")
            throw APIError.decodingFailed("\(decodingError)")
        }
    }

    @discardableResult
    private func send(
        path: String,
        method: String,
        body: Data? = nil
    ) async throws -> Bool {
        let request = try makeRequest(path: path, method: method, body: body)

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw APIError.cancelled
        } catch let urlError as URLError {
            if urlError.code == .notConnectedToInternet ||
               urlError.code == .networkConnectionLost {
                throw APIError.networkUnavailable
            }
            if urlError.code == .cancelled {
                throw APIError.cancelled
            }
            throw APIError.unknown(urlError.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299: return true
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        case 429: throw APIError.rateLimited
        case 500...599: throw APIError.serverError(httpResponse.statusCode)
        default: throw APIError.unknown("HTTP \(httpResponse.statusCode)")
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // PUBLIC ENDPOINT METHODS
    // ─────────────────────────────────────────────────────────────────────

    func fetchJobs(
        minScore: Int = 0,
        remote: Bool? = nil,
        visa: Bool? = nil,
        source: String? = nil,
        daysFresh: Int = 30,
        page: Int = 1,
        perPage: Int = 25
    ) async throws -> JobsPage {

        var queryItems = [
            URLQueryItem(name: "min_score",  value: "\(minScore)"),
            URLQueryItem(name: "days_fresh", value: "\(daysFresh)"),
            URLQueryItem(name: "page",       value: "\(page)"),
            URLQueryItem(name: "per_page",   value: "\(perPage)"),
        ]
        if let remote { queryItems.append(URLQueryItem(name: "remote", value: "\(remote)")) }
        if let visa   { queryItems.append(URLQueryItem(name: "visa",   value: "\(visa)")) }
        if let source { queryItems.append(URLQueryItem(name: "source", value: source)) }

        var components = URLComponents()
        components.queryItems = queryItems
        let queryString = components.percentEncodedQuery.map { "?\($0)" } ?? ""

        // Fetch the raw data so we can do partial decoding of the jobs array
        let request = try makeRequest(path: "/jobs\(queryString)")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown("Invalid response")
        }
        switch httpResponse.statusCode {
        case 200...299: break
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        case 500...599: throw APIError.serverError(httpResponse.statusCode)
        default: throw APIError.unknown("HTTP \(httpResponse.statusCode)")
        }

        // Parse the envelope
        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw APIError.decodingFailed("Response is not a JSON object")
        }

        let total   = envelope["total"]    as? Int ?? 0
        let pg      = envelope["page"]     as? Int ?? page
        let perPg   = envelope["per_page"] as? Int ?? perPage
        let hasMore = envelope["has_more"] as? Bool ?? false

        // Partially decode the jobs array — skip malformed records
        var jobs: [Job] = []
        if let rawJobs = envelope["jobs"] as? [[String: Any]] {
            var skipped = 0
            for rawJob in rawJobs {
                if let jobData = try? JSONSerialization.data(withJSONObject: rawJob),
                   let job = try? decoder.decode(Job.self, from: jobData) {
                    jobs.append(job)
                } else {
                    skipped += 1
                }
            }
            if skipped > 0 {
                print("⚠️ fetchJobs: skipped \(skipped) malformed Job records")
            }
        }

        return JobsPage(jobs: jobs, total: total, page: pg, perPage: perPg, hasMore: hasMore)
    }
    func fetchJob(id: String) async throws -> Job {
        return try await fetch(path: "/jobs/\(id)")
    }

    func fetchStats() async throws -> DashboardStats {
        return try await fetch(path: "/stats")
    }

    // ── Single-job outreach (used by JobDetailView) ───────────────────────

    func fetchOutreach(jobId: String) async throws -> OutreachMessage {
        return try await fetch(path: "/jobs/\(jobId)/outreach")
    }

    // ── Batch outreach (used by OutreachViewModel) ────────────────────────
    //
    // Fetches outreach for up to 50 jobs in ONE HTTP request instead of N.
    // The server returns [String: OutreachBatchItem] keyed by job ID.
    // We convert each item into a full OutreachMessage for the caller.
    //
    // WHY fetch() can be called here:
    //   fetch() is a private method of APIClient.
    //   fetchOutreachBatch() is also a method of APIClient (same class body).
    //   Private members are visible to all methods in the same type.

    func fetchOutreachBatch(jobIds: [String]) async throws -> [String: OutreachMessage] {
        guard !jobIds.isEmpty else { return [:] }

        // Cap at 50 to match the server-side limit
        let ids = jobIds.prefix(50).joined(separator: ",")

        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "ids", value: ids)]
        let queryString = components.percentEncodedQuery.map { "?\($0)" } ?? ""

        // Decode as [String: OutreachBatchItem] — the key is the job ID string
        let raw: [String: OutreachBatchItem] = try await fetch(
            path: "/jobs/outreach\(queryString)"
        )

        // Convert each OutreachBatchItem to a full OutreachMessage
        return raw.reduce(into: [:]) { dict, pair in
            dict[pair.key] = OutreachMessage(
                jobId:          pair.key,
                message:        pair.value.message,
                recruiterName:  pair.value.recruiterName,
                recruiterEmail: pair.value.recruiterEmail,
                linkedinUrl:    pair.value.linkedinUrl
            )
        }
    }

    func fetchJobsWithOutreach(page: Int = 1) async throws -> JobsPage {
        return try await fetchJobs(
            minScore: 45,
            daysFresh: 90,
            page: page,
            perPage: 20
        )
    }

    func applyToJob(jobId: String, stage: String) async throws {
        let body = try JSONEncoder().encode(["stage": stage])
        try await send(
            path: "/jobs/\(jobId)/apply",
            method: "POST",
            body: body
        )
    }

    func fetchApplications() async throws -> [Application] {
        return try await fetchArray(path: "/applications")
    }

    func updateApplication(
        applicationId: String,
        stage: String? = nil,
        notes: String? = nil
    ) async throws {
        var body: [String: String] = [:]
        if let stage { body["stage"] = stage }
        if let notes { body["notes"] = notes }

        let data = try JSONEncoder().encode(body)

        try await send(
            path: "/applications/\(applicationId)",
            method: "PATCH",
            body: data
        )
    }

    func checkHealth() async -> Bool {
        do {
            let _: DashboardStats = try await fetch(path: "/stats")
            return true
        } catch APIError.unauthorized {
            return false
        } catch {
            return false
        }
    }

    func runPipeline() async throws -> RunPipelineResponse {
        return try await fetch(path: "/run-pipeline", method: "POST")
    }

}   // ← end of APIClient class — ALL methods above are inside this brace
