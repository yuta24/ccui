import SwiftUI

struct EnvironmentVariablesSettingsView: View {
    @Environment(AppSettingsStore.self) private var store
    @State private var selection = Set<EnvironmentVariable.ID>()

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                Table($store.environmentVariables, selection: $selection) {
                    TableColumn("Name") { $variable in
                        TextField("KEY", text: $variable.key)
                            .font(.monoBody)
                    }
                    .width(min: 120, ideal: 160)

                    TableColumn("Value") { $variable in
                        TextField("value", text: $variable.value)
                            .font(.monoBody)
                    }
                    .width(min: 160, ideal: 240)
                }
                .tableStyle(.bordered)
                .alternatingRowBackgrounds()
                .frame(minHeight: 180)
                .contextMenu(forSelectionType: EnvironmentVariable.ID.self) { ids in
                    if !ids.isEmpty {
                        Button("Delete", role: .destructive) {
                            removeVariables(ids: ids)
                        }
                    }
                } primaryAction: { _ in }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 0) {
                        Button(action: { store.addVariable() }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                        .frame(width: 28, height: 22)

                        Divider()
                            .frame(height: 16)

                        Button(action: { removeVariables(ids: selection) }) {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.borderless)
                        .frame(width: 28, height: 22)
                        .disabled(selection.isEmpty)

                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.separator.opacity(0.2))
                    .overlay(alignment: .top) {
                        Divider()
                    }
                }
            } header: {
                Text("環境変数")
            } footer: {
                Text("ここで設定した環境変数は、新しい Claude セッションの起動時に渡されます。")
            }
        }
        .formStyle(.grouped)
        .onChange(of: store.settings.environmentVariables) {
            store.persist()
        }
    }

    private func removeVariables(ids: Set<EnvironmentVariable.ID>) {
        for id in ids {
            store.removeVariable(id: id)
        }
        selection.subtract(ids)
    }
}
