import Foundation
import LocalAuthentication
import SwiftUI

@Observable
final class AppLockManager {
    static let shared = AppLockManager()

    private(set) var isLocked = true
    private(set) var isAuthenticating = false
    private(set) var authenticationError: String?

    @ObservationIgnored
    @AppStorage("appLockEnabled") var isAppLockEnabled = false

    @ObservationIgnored
    private var lastBackgroundTime: Date?

    @ObservationIgnored
    private let lockTimeout: TimeInterval = 0 // Lock immediately when backgrounded

    private init() {
        // Start locked if app lock is enabled
        isLocked = isAppLockEnabled
    }

    // MARK: - Public Methods

    /// Check if biometric authentication is available on this device
    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Get the type of biometric available (Face ID, Touch ID, or none)
    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        @unknown default:
            return .none
        }
    }

    /// Authenticate the user with biometrics or device passcode
    func authenticate() async {
        guard isAppLockEnabled && isLocked else {
            isLocked = false
            return
        }

        guard !isAuthenticating else { return }

        await MainActor.run {
            isAuthenticating = true
            authenticationError = nil
        }

        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"

        let reason = "Unlock OnCall Scribe to access your triage records"

        do {
            // Try biometrics first, fall back to device passcode
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )

            await MainActor.run {
                isAuthenticating = false
                if success {
                    isLocked = false
                    authenticationError = nil
                }
            }
        } catch let error as LAError {
            await MainActor.run {
                isAuthenticating = false
                handleAuthError(error)
            }
        } catch {
            await MainActor.run {
                isAuthenticating = false
                authenticationError = "Authentication failed"
            }
        }
    }

    /// Lock the app (called when app goes to background)
    func lockApp() {
        guard isAppLockEnabled else { return }
        lastBackgroundTime = Date()
    }

    /// Check if app should be locked (called when app becomes active)
    func checkLockStatus() {
        guard isAppLockEnabled else {
            isLocked = false
            return
        }

        // If we have a background time, check if timeout has passed
        if let backgroundTime = lastBackgroundTime {
            let elapsed = Date().timeIntervalSince(backgroundTime)
            if elapsed >= lockTimeout {
                isLocked = true
            }
        } else {
            // No background time means app just launched
            isLocked = true
        }

        lastBackgroundTime = nil
    }

    /// Enable or disable app lock
    func setAppLockEnabled(_ enabled: Bool) async {
        if enabled {
            // Verify biometrics work before enabling
            let context = LAContext()
            let reason = "Enable app lock with biometrics"

            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: reason
                )

                await MainActor.run {
                    if success {
                        isAppLockEnabled = true
                        isLocked = false // Don't lock immediately after enabling
                    }
                }
            } catch {
                await MainActor.run {
                    isAppLockEnabled = false
                }
            }
        } else {
            await MainActor.run {
                isAppLockEnabled = false
                isLocked = false
            }
        }
    }

    // MARK: - Private Methods

    private func handleAuthError(_ error: LAError) {
        switch error.code {
        case .userCancel:
            authenticationError = nil // User cancelled, don't show error
        case .userFallback:
            authenticationError = nil // User chose passcode
        case .biometryNotAvailable:
            authenticationError = "Biometric authentication not available"
        case .biometryNotEnrolled:
            authenticationError = "No biometrics enrolled. Please set up Face ID or Touch ID in Settings."
        case .biometryLockout:
            authenticationError = "Biometrics locked. Please use your device passcode."
        case .authenticationFailed:
            authenticationError = "Authentication failed. Please try again."
        default:
            authenticationError = "Authentication error. Please try again."
        }
    }
}

// MARK: - Biometric Type

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID

    var name: String {
        switch self {
        case .none: return "Passcode"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        }
    }

    var icon: String {
        switch self {
        case .none: return "lock.fill"
        case .touchID: return "touchid"
        case .faceID: return "faceid"
        case .opticID: return "opticid"
        }
    }
}
