import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        if let stores = appDelegate.stores {
            TabView {
                GeneralSettingsView()
                    .tabItem {
                        Label("一般", systemImage: "gearshape")
                    }
                    .tag("general")
                ClaudeSettingsView()
                    .tabItem {
                        Label("Claude", systemImage: "terminal")
                    }
                    .tag("claude")
            }
            .tabViewStyle(.sidebarAdaptable)
            .frame(width: 600, height: 480)
            .environment(stores.appSettingsStore)
        }
    }
}
