import Foundation
import LocalAuthentication
import Observation

/// Face ID / Touch ID / passcode lock. The app starts locked, and locks again
/// when it has been in the background longer than the timeout.
@Observable
final class AppLock {
    static let timeoutKey = "lockTimeoutSeconds"
    static let defaultTimeout: TimeInterval = 120

    private(set) var isLocked = true
    private(set) var lastError: String?
    private var backgroundedAt: Date?

    var timeout: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: AppLock.timeoutKey)
        return stored > 0 ? stored : AppLock.defaultTimeout
    }

    func didEnterBackground() {
        backgroundedAt = .now
    }

    func didBecomeActive() {
        if let backgroundedAt, Date.now.timeIntervalSince(backgroundedAt) >= timeout {
            isLocked = true
        }
        backgroundedAt = nil
    }

    func lock() {
        isLocked = true
    }

    /// Returns true when the person authenticated.
    @MainActor
    func unlock() async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your case log"
            )
            if success {
                isLocked = false
                lastError = nil
            }
            return success
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
