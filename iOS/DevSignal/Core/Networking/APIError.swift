// Core/Networking/APIError.swift
//
// PURPOSE:
//   Defines all the ways a network call can fail.
//   Using an enum instead of generic Error means every failure
//   has a specific cause — easier to handle and display to the user.
//
// ERROR ENUM PATTERN:
//   In Python you raise specific exception types.
//   In Swift you define a typed enum that conforms to Error,
//   then throw it. Callers catch specific cases.

import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized           // 401 — wrong API key
    case notFound               // 404 — job doesn't exist
    case serverError(Int)       // 500+ — server crashed
    case decodingFailed(String) // JSON didn't match our struct
    case networkUnavailable     // no internet connection
    case rateLimited
    case cancelled              // request cancelled (e.g. SwiftUI task cancellation)
    case unknown(String)        // catch-all
    
    // errorDescription is shown to the user.
    // LocalizedError protocol requires this property.
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL. Check your settings."
        case .unauthorized:
            return "Invalid API key. Check your settings."
        case .notFound:
            return "Job not found."
        case .serverError(let code):
            return "Server error (\(code)). Try again later."
        case .decodingFailed(let detail):
            return "Data parsing error: \(detail)"
        case .networkUnavailable:
            return "No internet connection. Showing cached data."
        case .rateLimited:
            return "Pipeline ran recently — please wait a few minutes before trying again."
        case .unknown(let msg):
            return msg
        case .cancelled:
            return nil
        }
    }
}
