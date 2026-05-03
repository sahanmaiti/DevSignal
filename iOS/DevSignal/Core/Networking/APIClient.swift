// PURPOSE:
//   The single object responsible for all HTTP communication with your
//   FastAPI backend. Every network call in the app goes through here.
//
// DESIGN:
//   - One method per endpoint
//   - All methods are async throws (they take time and can fail)
//   - All methods are @MainActor (safe to call from ViewModels)
//   - The base URL and API key come from AppEnvironment.shared
//
// URLSession:
//   Apple's built-in HTTP client. Like Python's httpx or requests.
//   URLSession.shared is a singleton — one shared session for the app.
//
// HOW A REQUEST WORKS:
//   1. Build a URLRequest (URL + headers + method + body)
//   2. await URLSession.shared.data(for: request) → (Data, URLResponse)
//   3. Check the HTTP status code
//   4. Decode Data → our Codable struct
//   5. Return the struct (or throw an error)

import Foundation

@MainActor
final class APIClient {
    
    // Singleton — one instance for the whole app
    static let shared = APIClient()
    private init() {}
    
    // JSONDecoder shared instance — configure it once here
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // This setting is NOT used here because we handle date strings
        // manually in our models, but it's good practice to set it:
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    
    // ── Private helper: build a URLRequest with auth header ───────────────
    //
    // Every request to your API needs:
    //   1. The correct base URL prepended
    //   2. The X-API-Key header attached
    //   3. Content-Type: application/json for POST/PATCH requests
    //
    // This helper handles all three so individual methods stay clean.
    
    private func makeRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) throws -> URLRequest {
        
        let base = AppEnvironment.shared.baseURL
        let key  = AppEnvironment.shared.apiKey
        
        guard let url = URL(string: base + path) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(key, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15  // fail after 15 seconds (not 60s default)
        
        if let body {
            request.httpBody = body
        }
        
        return request
    }
    
    // ── Private helper: execute a request and decode the response ─────────
    //
    // Generic function: <T: Codable> means T can be ANY type that is Codable.
    // So fetch(path:) can return a Job, a JobsPage, DashboardStats — anything.
    // You call it like: try await fetch(path: "/jobs") as JobsPage
    // Swift infers what T is from the return type you expect.
    
    private func fetch<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        
        let request = try makeRequest(path: path, method: method, body: body)
        
        let (data, response): (Data, URLResponse)
        
        do {
            // await: pause here while the network request is in flight.
            // This does NOT block the main thread — other UI work continues.
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            // URLError means the request never reached the server
            // (no wifi, server unreachable, timeout, etc.)
            if urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                throw APIError.networkUnavailable
            }
            throw APIError.unknown(urlError.localizedDescription)
        }
        
        // Cast to HTTPURLResponse to read the status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown("Invalid response type")
        }
        
        // Check HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            break  // success — continue to decode
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.unknown("HTTP \(httpResponse.statusCode)")
        }
        
        // Decode the JSON data into our expected type T
        do {
            return try decoder.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            // DecodingError gives us detailed information about what went wrong.
            // We log this to the console for debugging.
            print("❌ Decoding error for \(T.self): \(decodingError)")
            throw APIError.decodingFailed("\(decodingError)")
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────
    // PUBLIC ENDPOINT METHODS
    // One method per API endpoint. Clean, readable, typed.
    // ─────────────────────────────────────────────────────────────────────
    
    // ── GET /jobs ─────────────────────────────────────────────────────────
    // Builds the query string from the filter parameters.
    // URLComponents handles URL encoding automatically (spaces → %20 etc.)
    
    func fetchJobs(
        minScore: Int = 0,
        remote: Bool? = nil,
        visa: Bool? = nil,
        source: String? = nil,
        daysFresh: Int = 30,
        page: Int = 1,
        perPage: Int = 25
    ) async throws -> JobsPage {
        
        // Build query parameters
        var components = URLComponents()
        var queryItems = [URLQueryItem]()
        
        queryItems.append(URLQueryItem(name: "min_score",  value: "\(minScore)"))
        queryItems.append(URLQueryItem(name: "days_fresh", value: "\(daysFresh)"))
        queryItems.append(URLQueryItem(name: "page",       value: "\(page)"))
        queryItems.append(URLQueryItem(name: "per_page",   value: "\(perPage)"))
        
        if let remote { queryItems.append(URLQueryItem(name: "remote", value: "\(remote)")) }
        if let visa   { queryItems.append(URLQueryItem(name: "visa",   value: "\(visa)")) }
        if let source { queryItems.append(URLQueryItem(name: "source", value: source)) }
        
        components.queryItems = queryItems
        let queryString = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        
        return try await fetch(path: "/jobs\(queryString)")
    }
    
    // ── GET /jobs/{id} ────────────────────────────────────────────────────
    
    func fetchJob(id: String) async throws -> Job {
        return try await fetch(path: "/jobs/\(id)")
    }
    
    // ── GET /stats ────────────────────────────────────────────────────────
    
    func fetchStats() async throws -> DashboardStats {
        return try await fetch(path: "/stats")
    }
    // ── GET /jobs/{id}/outreach ───────────────────────────────────────────────
    // Fetches the pre-generated outreach message and recruiter contact info.
    // Called when a user opens the Outreach tab or taps "View Outreach" in
    // job detail. The message was already generated by Groq during the pipeline
    // run — this is just a DB read, not a new AI call.

    func fetchOutreach(jobId: String) async throws -> OutreachMessage {
        return try await fetch(path: "/jobs/\(jobId)/outreach")
    }

    // ── GET /jobs (outreach filter) ───────────────────────────────────────────
    // Fetches jobs that have outreach messages generated (score ≥ 45).
    // Used by OutreachViewModel to populate the Outreach tab list.
    // We reuse fetchJobs with a high minScore since only scored ≥ 45 get messages.

    func fetchJobsWithOutreach(page: Int = 1) async throws -> JobsPage {
        return try await fetchJobs(
            minScore: 45,
            daysFresh: 90,   // wider window for outreach — older jobs still relevant
            page: page,
            perPage: 20
        )
    }
    
    // ── POST /jobs/{id}/apply ─────────────────────────────────────────────
    // This sends a JSON body, so we encode the stage dict to Data first.
    
    func applyToJob(jobId: String, stage: String) async throws {
        let body = try JSONEncoder().encode(["stage": stage])
        // We use Void as T because we only care if it succeeds, not the response
        let _: [String: String] = try await fetch(
            path: "/jobs/\(jobId)/apply",
            method: "POST",
            body: body
        )
    }
    
    // ── GET /health ───────────────────────────────────────────────────────
    // Used during onboarding to verify the server is reachable.
    // Returns true if the server responds, false otherwise.
    
    func checkHealth() async -> Bool {
        do {
            let _: [String: String] = try await fetch(path: "/health")
            return true
        } catch {
            return false
        }
    }
}
