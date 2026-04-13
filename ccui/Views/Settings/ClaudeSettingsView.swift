import SwiftUI

struct ClaudeSettingsView: View {
    var body: some View {
        Form {
            NavigationLink {
                EnvironmentVariablesSettingsView()
                    .navigationTitle("環境変数")
            } label: {
                Label("環境変数", systemImage: "list.bullet.rectangle")
            }
        }
        .formStyle(.grouped)
    }
}
