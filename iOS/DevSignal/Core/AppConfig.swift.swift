// AppConfig.swift
//
// Single source of truth for backend configuration.
// Update productionURL after you complete the DuckDNS + Nginx setup.

import Foundation

enum AppConfig {

    // ── Your hosted backend URL ───────────────────────────────────────────
    // Replace this after Part 3 when you have your DuckDNS domain working.
    // Format: https://your-chosen-name.duckdns.org
    static let productionURL = "https://PLACEHOLDER.duckdns.org"

    // ── Pipeline API key ──────────────────────────────────────────────────
    // Must match the PIPELINE_API_KEY value in your server's .env file.
    static let apiKey = "PLACEHOLDER_API_KEY"

    // Used by AppEnvironment and APIClient throughout the app
    static var baseURL: String { productionURL }
}
