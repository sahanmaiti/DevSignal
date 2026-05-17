// PURPOSE:
//   Manages all state for the Tracker Kanban board.
//
// KEY DESIGN: OPTIMISTIC UPDATES
//   When the user moves a card, we update the UI immediately (optimistic),
//   then send the PATCH request in the background.
//   If the request fails, we revert the card to its original column.
//
// DATA STRUCTURE:
//   applications: [Application] — flat list from the API
//   stageOverrides: [String: ApplicationStage] — local changes not yet
//     confirmed by the server. cards(for:) checks this first.

// Features/Tracker/TrackerViewModel.swift

import Foundation
import Combine

@MainActor
final class TrackerViewModel: ObservableObject {
    
    @Published var applications: [Application] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var movedCardId: String? = nil
    @Published private var stageOverrides: [String: ApplicationStage] = [:]
    
    private let api: any APIClientProtocol

    init(api: (any APIClientProtocol)? = nil) {
        self.api = api ?? APIClient.shared
    }
    
    // ── Derived ───────────────────────────────────────────────────────────
    
    func cards(for stage: ApplicationStage) -> [Application] {
        applications
            .filter { app in
                let effective = stageOverrides[app.applicationId] ?? app.stage
                return effective == stage
            }
            .sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }
    }
    
    var totalCount: Int { applications.count }
    
    func countFor(_ stage: ApplicationStage) -> Int {
        cards(for: stage).count
    }
    
    // ── Load / Refresh ────────────────────────────────────────────────────
    
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            applications = try await api.fetchApplications()
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func refresh() async {
        do {
            // Clear overrides FIRST so server is source of truth after refresh
            stageOverrides = [:]
            applications = try await api.fetchApplications()
            errorMessage = nil
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func clearOverrides() {
        stageOverrides = [:]
    }
    
    // ── Move card (optimistic) ────────────────────────────────────────────
    
    func moveCard(_ application: Application, to newStage: ApplicationStage) async {
        let currentOverride = stageOverrides[application.applicationId]
        let oldStage = currentOverride ?? application.stage
        guard oldStage != newStage else { return }
        
        // 1. Optimistic update — UI moves immediately
        stageOverrides[application.applicationId] = newStage
        
        // 2. Brief highlight animation
        movedCardId = application.applicationId
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            if movedCardId == application.applicationId { movedCardId = nil }
        }
        
        // 3. Persist to server
        do {
            try await api.updateApplication(
                applicationId: application.applicationId,
                stage:         newStage.rawValue,
                notes:         nil
            )
            
            // SUCCESS: update the local array directly — no re-fetch needed.
            // This avoids the race where a second in-flight fetch overwrites
            // a concurrent optimistic move.
            if let idx = applications.firstIndex(where: {
                $0.applicationId == application.applicationId
            }) {
                applications[idx] = application.withStage(newStage)
            }
            
            // Remove the override now that the local array is authoritative.
            stageOverrides.removeValue(forKey: application.applicationId)
            
        } catch {
            // FAILURE: revert the optimistic update
            stageOverrides[application.applicationId] = oldStage
            errorMessage = "Couldn't update stage. Check your connection."
        }
    }
    
    // ── Save notes ────────────────────────────────────────────────────────
    
    func saveNotes(for application: Application, notes: String) async {
        do {
            try await api.updateApplication(
                applicationId: application.applicationId,
                stage:         nil,
                notes:         notes
            )
            // Update local array directly instead of re-fetching
            if applications.contains(where: { $0.applicationId == application.applicationId }) {
                // notes isn't in Application's withStage helper, so do a refresh
                // only after notes save (single-user action, no race risk here)
                if let fresh = try? await api.fetchApplications() {
                    applications = fresh
                }
            }
        } catch {
            errorMessage = "Couldn't save notes."
        }
    }
}
