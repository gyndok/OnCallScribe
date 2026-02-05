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

                // App Name
                Text("OnCall Scribe")
                    .font(.title.weight(.bold))
                    .foregroundColor(Color.txtPrimary)

                Text("Locked")
                    .font(.subheadline)
                    .foregroundColor(Color.txtSecondary)

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
                            } else {
                                Image(systemName: appLockManager.biometricType.icon)
                                    .font(.title2)
                            }

                            Text(unlockButtonText)
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(appLockManager.isAuthenticating)
                    .padding(.horizontal, 32)

                    // Error message
                    if let error = appLockManager.authenticationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Color.prioEmergent)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                Spacer()

                // Privacy note
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title3)
                        .foregroundColor(Color.txtTertiary)

                    Text("Your triage records are protected")
                        .font(.caption)
                        .foregroundColor(Color.txtTertiary)
                }
                .padding(.bottom, 32)
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
