import SwiftUI

struct AppSettingsView: View {
    var body: some View {
        TabView {
            ClaudeSettingsView()
                .tabItem {
                    Label("Claude", systemImage: "terminal")
                }
                .tag("claude")
        }
        .tabViewStyle(.sidebarAdaptable)
        .frame(width: 560, height: 400)
    }
}
