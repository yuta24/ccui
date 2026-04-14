import SwiftUI

struct PermissionsRuleEditorView: View {
    @Bindable var store: PermissionsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            listKindPicker
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            ruleListContent
        }
    }

    // MARK: - List Kind Picker

    private var listKindPicker: some View {
        HStack(spacing: 4) {
            ForEach(PermissionListKind.allCases) { kind in
                Button {
                    store.selectedListKind = kind
                } label: {
                    Text(kind.rawValue)
                        .font(.uiCaption)
                        .foregroundStyle(store.selectedListKind == kind ? Color.accent : Color.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(store.selectedListKind == kind ? Color.accentSubtle : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                store.addRule()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Add")
                        .font(.uiCaption)
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Rule List

    private var ruleListContent: some View {
        let rules = store.currentRules
        return Group {
            if rules.isEmpty && !showUserDenyReference {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if showUserDenyReference {
                            userDenyReferenceSection
                            Rectangle()
                                .fill(Color.borderSubtle)
                                .frame(height: 1)
                        }

                        ForEach(rules) { rule in
                            ruleRow(rule)
                            Rectangle()
                                .fill(Color.borderSubtle)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private var showUserDenyReference: Bool {
        store.selectedLevel == .worktree
            && store.selectedListKind == .deny
            && !store.userDenyRules.isEmpty
    }

    // MARK: - Rule Row

    private func ruleRow(_ rule: PermissionRule) -> some View {
        let isSelected = store.selectedRuleID == rule.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                store.selectedRuleID = isSelected ? nil : rule.id
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isSelected ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 10)

                    if rule.value.isEmpty {
                        Text("(new rule)")
                            .font(.uiCaption)
                            .foregroundStyle(Color.textTertiary)
                            .italic()
                    } else {
                        HStack(spacing: 4) {
                            Text(rule.toolName)
                                .font(.uiCaption)
                                .foregroundStyle(Color.accent)
                            if let spec = rule.specifier {
                                Text(spec)
                                    .font(.uiCaptionMono)
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }

                    Spacer()

                    Button {
                        store.removeRule(rule)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .background(isSelected ? Color.surfaceHover : Color.clear)
            }
            .buttonStyle(.plain)

            if isSelected {
                ruleDetail(rule)
            }
        }
    }

    // MARK: - Rule Detail

    private func ruleDetail(_ rule: PermissionRule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Rule")
                    .font(.uiCaption)
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 36, alignment: .trailing)
                TextField("e.g. Bash(swift package:*)", text: Binding(
                    get: { rule.value },
                    set: { store.updateRule(rule, value: $0) }
                ))
                .font(.uiCaptionMono)
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.surfaceBase)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.borderDefault, lineWidth: 1)
                )
            }

            // Wildcard preview
            if let spec = rule.specifier, spec.contains("*") {
                wildcardPreview(rule)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.surfaceBase)
    }

    // MARK: - Wildcard Preview

    private func wildcardPreview(_ rule: PermissionRule) -> some View {
        let samples = PermissionRule.generateSamples(for: rule)
        return VStack(alignment: .leading, spacing: 3) {
            Text("Pattern preview")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)

            ForEach(Array(samples.enumerated()), id: \.offset) { _, pair in
                HStack(spacing: 6) {
                    Image(systemName: pair.1 ? "checkmark" : "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(pair.1 ? Color.statusClean : Color.textTertiary)
                        .frame(width: 12)
                    Text(pair.0)
                        .font(.uiCaptionMono)
                        .foregroundStyle(pair.1 ? Color.textPrimary : Color.textTertiary)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - User Deny Reference

    private var userDenyReferenceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("User deny (read-only)")
                    .font(.uiCaption)
                    .foregroundStyle(Color.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text("\(store.userDenyRules.count)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ForEach(store.userDenyRules) { rule in
                HStack(spacing: 8) {
                    Image(systemName: "lock")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textTertiary)
                    Text(rule.value)
                        .font(.uiCaptionMono)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
            }
        }
        .background(Color.surfaceBase)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 24))
                .foregroundStyle(Color.textTertiary)
            Text("No \(store.selectedListKind.rawValue.lowercased()) rules")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
            Button {
                store.addRule()
            } label: {
                Text("Add Rule")
                    .font(.uiCaption)
                    .foregroundStyle(Color.surfaceBase)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
