// PURPOSE:
//   A Swift concurrency-safe semaphore for limiting concurrent async tasks.
//   Used by OutreachViewModel to cap simultaneous outreach HTTP requests
//   so we don't saturate the FastAPI connection pool (maxconn=5).
//
// USAGE:
//   let semaphore = AsyncSemaphore(limit: 5)
//   await semaphore.wait()
//   defer { semaphore.signal() }
//   // ... do the work ...

import Foundation

/// Actor-based semaphore that limits concurrent async task execution.
///
/// Using an actor guarantees that `wait()` and `signal()` are
/// never called simultaneously from different tasks — the actor
/// serialises access to `availableSlots` automatically.
actor AsyncSemaphore {

    private var availableSlots: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.availableSlots = limit
    }

    /// Waits until a slot is available, then claims it.
    /// Suspends the calling task without blocking a thread.
    func wait() async {
        if availableSlots > 0 {
            // Slot available — claim it immediately without suspending
            availableSlots -= 1
            return
        }

        // No slots — suspend until signal() is called
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// Releases a slot.  If tasks are waiting, resumes the oldest one.
    func signal() {
        if let waiter = waiters.first {
            // Hand the slot directly to the next waiter
            // (don't increment availableSlots — it stays claimed)
            waiters.removeFirst()
            waiter.resume()
        } else {
            // No waiters — return the slot to the pool
            availableSlots += 1
        }
    }
}
