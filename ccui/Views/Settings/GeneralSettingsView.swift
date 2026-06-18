import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppSettingsStore.self) private var settingsStore

    var body: some View {
        @Bindable var store = settingsStore
        Form {
            Picker("Appearance", selection: $store.appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .formStyle(.grouped)
    }
}
