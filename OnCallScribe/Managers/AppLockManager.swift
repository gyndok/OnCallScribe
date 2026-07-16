import Foundation
import LocalAuthentication
import Security
import SwiftUI
import UIKit

@MainActor
@Observable
final class AppLockManager {
    static let shared = AppLockManager()

    private(set) var isLocked = true
    private(set) var isAuthenticating = false
    private(set) var authenticationError: String?

    /// True while the app is inactive (app switcher, Notification Center,
    /// incoming call). Shows a privacy cover without requiring re-auth.
    private(set) var isShielded = false

    /// Whether the app-lock feature is enabled. Backed by the Keychain
    /// (OR'd with the legacy UserDefaults flag) so the flag can't be
    /// disabled by editing the preferences plist, and so existing users'
    /// settings migrate automatically.
    private(set) var isAppLockEnabled: Bool

    @ObservationIgnored
    private var lastBackgroundTime: Date?

    @ObservationIgnored
    private let lockTimeout: TimeInterval = 0 // Lock immediately when backgrounded

    /// Overlay window that hosts the lock screen / privacy shield. A separate
    /// window at a high level covers *presented sheets* too — a plain ZStack
    /// overlay in the root view renders below active presentations.
    @ObservationIgnored
    private var shieldWindow: UIWindow?

    private init() {
        let enabled = (KeychainFlag.read() ?? false) || UserDefaults.standard.bool(forKey: "appLockEnabled")
        isAppLockEnabled = enabled
        // Start locked if app lock is enabled
        isLocked = enabled
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
        default:
            return .none
        }
    }

    /// Respond to scene phase changes. Called from the App's scenePhase handler.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            lockApp()
        case .inactive:
            shieldApp()
        case .active:
            isShielded = false
            checkLockStatus()
        @unknown default:
            break
        }
        updateShieldWindow()
    }

    /// Authenticate the user with biometrics or device passcode
    func authenticate() async {
        guard isAppLockEnabled && isLocked else {
            isLocked = false
            updateShieldWindow()
            return
        }

        // The class is @MainActor, so this guard-and-set happens atomically
        // with respect to other callers — no double Face ID prompt.
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authenticationError = nil
        defer {
            isAuthenticating = false
            updateShieldWindow()
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

            if success {
                isLocked = false
                authenticationError = nil
            }
        } catch let error as LAError {
            handleAuthError(error)
        } catch {
            authenticationError = "Authentication failed"
        }
    }

    /// Lock the app (called when app goes to background). Sets isLocked
    /// immediately so the lock screen — not patient data — is what iOS
    /// captures for the app-switcher snapshot.
    func lockApp() {
        guard isAppLockEnabled else { return }
        lastBackgroundTime = Date()
        isLocked = true
        isShielded = false
        updateShieldWindow()
    }

    /// Cover the UI while the app is inactive (app switcher preview,
    /// Notification Center, incoming call) without forcing re-auth.
    private func shieldApp() {
        guard isAppLockEnabled else { return }
        isShielded = true
    }

    /// Reconcile lock state when the app becomes active.
    func checkLockStatus() {
        guard isAppLockEnabled else {
            isLocked = false
            updateShieldWindow()
            return
        }

        if let backgroundTime = lastBackgroundTime {
            // Returned from the background: honor the timeout (0 = always lock).
            let elapsed = Date().timeIntervalSince(backgroundTime)
            isLocked = elapsed >= lockTimeout
            lastBackgroundTime = nil
        }
        // No background time: this is an inactive→active bounce (Control
        // Center, the Face ID sheet itself). Leave the current lock state
        // alone — re-locking here raced authenticate() and caused
        // unlock/re-prompt loops.

        updateShieldWindow()
    }

    /// Enable or disable app lock. Both directions require the device owner
    /// to authenticate — otherwise anyone holding the momentarily unlocked
    /// phone could silently disable protection.
    func setAppLockEnabled(_ enabled: Bool) async {
        let context = LAContext()
        let reason = enabled
            ? "Enable app lock with biometrics"
            : "Authenticate to turn off app lock"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )

            if success {
                isAppLockEnabled = enabled
                persistEnabledFlag(enabled)
                isLocked = false // Don't lock immediately after toggling
            }
        } catch {
            // Auth failed or was cancelled — leave the setting unchanged.
        }
        updateShieldWindow()
    }

    // MARK: - Private Methods

    private func persistEnabledFlag(_ enabled: Bool) {
        KeychainFlag.write(enabled)
        // Keep the legacy key in sync so the OR-fallback stays coherent.
        UserDefaults.standard.set(enabled, forKey: "appLockEnabled")
    }

    private func updateShieldWindow() {
        let shouldShow = isAppLockEnabled && (isLocked || isShielded)

        if shouldShow {
            guard shieldWindow == nil else { return }
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            guard let scene = scenes.first(where: { $0.activationState == .foregroundActive })
                    ?? scenes.first(where: { $0.activationState == .foregroundInactive })
                    ?? scenes.first else {
                return
            }
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            window.rootViewController = UIHostingController(rootView: LockOverlayView())
            window.isHidden = false
            shieldWindow = window
        } else {
            shieldWindow?.isHidden = true
            shieldWindow = nil
        }
    }

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

// MARK: - Keychain-backed flag

/// Minimal keychain storage for the app-lock flag. Unlike UserDefaults, a
/// keychain item can't be flipped by editing a backed-up preferences plist.
private enum KeychainFlag {
    private static let service = "com.oncallscribe.app"
    private static let account = "appLockEnabled"

    static func read() -> Bool? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let byte = data.first else {
            return nil
        }
        return byte == 1
    }

    static func write(_ value: Bool) {
        let data = Data([value ? 1 : 0])
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
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
