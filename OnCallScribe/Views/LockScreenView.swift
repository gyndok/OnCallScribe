import SwiftUI

struct LockScreenView: View {
    @State private var appLockManager = AppLockManager.shared

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App Icon
                Image("LaunchImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .accessibilityHidden(true)

                // App Name
                VStack(spacing: 8) {
                    Text("OnCall Scribe")
                        .font(.title.weight(.bold))
                        .foregroundColor(Color.txtPrimary)

                    Text("Locked")
                        .font(.subheadline)
                        .foregroundColor(Color.txtSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("OnCall Scribe is locked")

                Spacer()

                // Unlock Button
                VStack(spacing: 16) {
                    Button {
                        HapticFeedback.impact()
                        Task {
                            await appLockManager.authenticate()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if appLockManager.isAuthenticating {
                                ProgressView()
                                    .tint(.white)
                                    .accessibilityHidden(true)
                            } else {
                                Image(systemName: appLockManager.biometricType.icon)
                                    .font(.title2)
                                    .accessibilityHidden(true)
                            }

                            Text(unlockButtonText)
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44) // Minimum touch target
                        .padding(.vertical, 16)
                        .background(Color.accentTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(appLockManager.isAuthenticating)
                    .padding(.horizontal, 32)
                    .accessibilityLabel(unlockButtonText)
                    .accessibilityHint(appLockManager.isAuthenticating ? "Authentication in progress" : "Double tap to authenticate")

                    // Error message
                    if let error = appLockManager.authenticationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Color.prioEmergent)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .accessibilityLabel("Error: \(error)")
                    }
                }

                Spacer()

                // Privacy note
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title3)
                        .foregroundColor(Color.txtTertiary)
                        .accessibilityHidden(true)

                    Text("Your triage records are protected")
                        .font(.caption)
                        .foregroundColor(Color.txtTertiary)
                }
                .padding(.bottom, 32)
                .accessibilityElement(children: .combine)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Auto-trigger authentication when view appears
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
                await appLockManager.authenticate()
            }
        }
    }

    private var unlockButtonText: String {
        if appLockManager.isAuthenticating {
            return "Authenticating..."
        }

        switch appLockManager.biometricType {
        case .faceID:
            return "Unlock with Face ID"
        case .touchID:
            return "Unlock with Touch ID"
        case .opticID:
            return "Unlock with Optic ID"
        case .none:
            return "Unlock with Passcode"
        }
    }
}

#Preview {
    LockScreenView()
}
