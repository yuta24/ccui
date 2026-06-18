import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        if let stores = appDelegate.stores {
            TabView {
                Tab("一般", systemImage: "gearshape") {
                    GeneralSettingsView()
                }
                Tab("Claude", systemImage: "terminal") {
                    ClaudeSettingsView()
                }
            }
            .frame(width: 600, height: 480)
            .environment(stores.appSettingsStore)
        }
    }
}
