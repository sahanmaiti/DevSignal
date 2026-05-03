// PURPOSE:
//   Manages all the state and data logic for the Discover tab.
//   The View never calls the API directly — it just reads from here
//   and calls methods here. This keeps the View clean and testable.
//
// @MainActor:
//   All @Published property updates must happen on the main thread
//   (UI thread). @MainActor guarantees this automatically.
//
// ObservableObject + @Published:
//   ObservableObject makes this class watchable by SwiftUI.
//   @Published means: when this property changes, notify all views
//   that are watching this ViewModel to redraw themselves.
//
// Task { }:
//   Task is Swift's way to start async work from a non-async context.
//   SwiftUI's .onAppear modifier is not async, so we wrap async calls
//   in Task { await ... } to bridge the gap.

import Foundation
import Combine

@MainActor
final class DiscoverViewModel: ObservableObject {
    
    // ── Published state — views watch these ───────────────────────────────
    
    @Published var jobs: [Job] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false   // for pagination — loading page 2+
    @Published var errorMessage: String? = nil
    @Published var hasMore = false
    @Published var totalCount = 0
    
    // ── Filter state ──────────────────────────────────────────────────────
    // These control what the API query returns.
    // When the user changes a filter, we reset and reload.
    
    @Published var minScore: Int = 0
    @Published var remoteOnly: Bool = false
    @Published var visaOnly: Bool = false
    @Published var daysFresh: Int = 30
    
    // ── Private state ─────────────────────────────────────────────────────
    
    private var currentPage = 1
    private let api = APIClient.shared
    
    // ── Initial load ──────────────────────────────────────────────────────
    // Called when the Discover tab appears for the first time.
    
    func loadJobs() async {
        // Don't start a new load if one is already running
        guard !isLoading else { return }
        
        currentPage = 1
        isLoading = true
        errorMessage = nil
        
        do {
            let page = try await api.fetchJobs(
                minScore: minScore,
                remote: remoteOnly ? true : nil,
                visa: visaOnly ? true : nil,
                daysFresh: daysFresh,
                page: 1,
                perPage: 25
            )
            
            // Replace the list with fresh results
            jobs = page.jobs
            hasMore = page.hasMore
            totalCount = page.total
            
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // ── Load next page (called when user scrolls to the bottom) ───────────
    
    func loadNextPage() async {
        guard hasMore && !isLoadingMore && !isLoading else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            let page = try await api.fetchJobs(
                minScore: minScore,
                remote: remoteOnly ? true : nil,
                visa: visaOnly ? true : nil,
                daysFresh: daysFresh,
                page: currentPage,
                perPage: 25
            )
            
            // APPEND new jobs to the existing list (don't replace)
            jobs.append(contentsOf: page.jobs)
            hasMore = page.hasMore
            totalCount = page.total
            
        } catch {
            // On pagination error, just stop — don't show an error banner
            // because the user already has data on screen
            currentPage -= 1  // revert so they can try again
        }
        
        isLoadingMore = false
    }
    
    // ── Refresh (pull-to-refresh) ─────────────────────────────────────────
    // Same as loadJobs() but can be called from a refreshable modifier.
    
    func refresh() async {
        currentPage = 1
        
        do {
            let page = try await api.fetchJobs(
                minScore: minScore,
                remote: remoteOnly ? true : nil,
                visa: visaOnly ? true : nil,
                daysFresh: daysFresh,
                page: 1,
                perPage: 25
            )
            jobs = page.jobs
            hasMore = page.hasMore
            totalCount = page.total
            errorMessage = nil
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // ── Apply filters (resets and reloads) ────────────────────────────────
    
    func applyFilters(minScore: Int, remoteOnly: Bool, visaOnly: Bool, daysFresh: Int) async {
        self.minScore   = minScore
        self.remoteOnly = remoteOnly
        self.visaOnly   = visaOnly
        self.daysFresh  = daysFresh
        await loadJobs()
    }
}
