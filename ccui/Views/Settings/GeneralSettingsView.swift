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

            Section("Font") {
                Picker("Font Family", selection: $store.fontName) {
                    ForEach(AppSettingsStore.availableMonospacedFonts, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }

                HStack {
                    Text("Font Size")
                    Spacer()
                    TextField("", value: $store.fontSize, format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                    Stepper(
                        "",
                        value: $store.fontSize,
                        in: AppSettings.minFontSize...AppSettings.maxFontSize,
                        step: 1
                    )
                    .labelsHidden()
                }

                Text("The quick brown fox jumps over the lazy dog")
                    .font(.custom(store.fontName, size: store.fontSize))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
}
