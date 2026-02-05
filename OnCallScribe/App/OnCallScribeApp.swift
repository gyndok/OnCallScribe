import SwiftUI
import SwiftData

@main
struct OnCallScribeApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    @State private var appLockManager = AppLockManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TriageRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none  // No CloudKit - local only for HIPAA compliance
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasCompletedOnboarding {
                    ContentView()
                } else {
                    OnboardingView()
                }

                // Lock screen overlay
                if appLockManager.isAppLockEnabled && appLockManager.isLocked {
                    LockScreenView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: appLockManager.isLocked)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                appLockManager.lockApp()
            case .active:
                appLockManager.checkLockStatus()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
