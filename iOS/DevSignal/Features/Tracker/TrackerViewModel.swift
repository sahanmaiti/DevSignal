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

import Foundation
import Combine

@MainActor
final class TrackerViewModel: ObservableObject {

    // ── Published state ───────────────────────────────────────────────────
    @Published var applications: [Application] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var movedCardId: String? = nil   // briefly highlights a moved card

    private let api = APIClient.shared

    // Tracks local stage changes not yet confirmed by the server.
    // Key: applicationId, Value: overridden stage.
    // cards(for:) checks this dict first before using the server value.
    @Published private var stageOverrides: [String: ApplicationStage] = [:]

    // ── Derived: cards per stage ──────────────────────────────────────────
    // Single definition — uses stageOverrides for optimistic UI.
    // Called by TrackerView to get the card list for each column.

    func cards(for stage: ApplicationStage) -> [Application] {
        applications
            .filter { app in
                // Use local override if one exists, otherwise use server value
                let effectiveStage = stageOverrides[app.applicationId] ?? app.stage
                return effectiveStage == stage
            }
            .sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }
    }

    // Total application count across all stages
    var totalCount: Int { applications.count }

    // ── Load ──────────────────────────────────────────────────────────────

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            applications = try await api.fetchApplications()
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // ── Refresh ───────────────────────────────────────────────────────────

    func refresh() async {
        do {
            applications = try await api.fetchApplications()
            errorMessage = nil
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // ── Clear overrides after refresh ─────────────────────────────────────
    // Called by pull-to-refresh so server becomes source of truth again.

    func clearOverrides() {
        stageOverrides = [:]
    }

    // ── Move card to a new stage (optimistic update) ──────────────────────
    //
    // HOW IT WORKS:
    // 1. Save old stage for rollback
    // 2. Write to stageOverrides immediately → UI rerenders with new column
    // 3. Send PATCH to server in background
    // 4. On failure → revert stageOverrides → UI reverts → show error

    func moveCard(_ application: Application, to newStage: ApplicationStage) async {
        let oldStage = stageOverrides[application.applicationId] ?? application.stage

        // Guard: no-op if already in this stage
        guard oldStage != newStage else { return }

        // Step 1: Optimistic update
        stageOverrides[application.applicationId] = newStage

        // Trigger a brief highlight on the moved card
        movedCardId = application.applicationId
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            if movedCardId == application.applicationId {
                movedCardId = nil
            }
        }

        // Step 2: Persist to server
        do {
            try await api.updateApplication(
                applicationId: application.applicationId,
                stage: newStage.rawValue
            )
        } catch {
            // Step 3: Revert on failure
            stageOverrides[application.applicationId] = oldStage
            errorMessage = "Failed to update stage. Please try again."
        }
    }

    // ── Save notes ────────────────────────────────────────────────────────

    func saveNotes(for application: Application, notes: String) async {
        do {
            try await api.updateApplication(
                applicationId: application.applicationId,
                notes: notes
            )
            // Re-fetch so the notes appear correctly next time the card opens
            await refresh()
        } catch {
            errorMessage = "Failed to save notes."
        }
    }
}
