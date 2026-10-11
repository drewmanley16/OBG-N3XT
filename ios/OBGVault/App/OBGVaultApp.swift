import SwiftUI

@main
struct OBGVaultApp: App {
    @State private var model = AppModel()

    init() { Notifications.shared.setUp() }

    var body: some Scene {
        WindowGroup {
            Group {
                if model.registration == nil { OnboardingView() } else { HomeView() }
            }
            .environment(model)
            .tint(Theme.accent)
            .preferredColorScheme(.dark)
            .task { model.startListening() }
        }
    }
}
