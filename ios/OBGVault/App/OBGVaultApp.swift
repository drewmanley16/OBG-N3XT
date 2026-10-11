import SwiftUI

@main
struct OBGVaultApp: App {
    @State private var store = VaultStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                WalletView()
                    .tabItem { Label("Wallet", systemImage: "wallet.pass") }
                ProviderView()
                    .tabItem { Label("Provider", systemImage: "stethoscope") }
            }
            .environment(store)
            .tint(Theme.accent)
            .preferredColorScheme(.dark)
        }
    }
}
