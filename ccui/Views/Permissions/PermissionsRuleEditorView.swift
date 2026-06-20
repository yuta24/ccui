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
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(PermissionListKind.allCases) { kind in
                        Button {
                            store.selectedListKind = kind
                        } label: {
                            Text(kind.rawValue)
                                .font(.uiCaption)
                                .foregroundStyle(store.selectedListKind == kind ? Color.accent : Color.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: PanelMetrics.buttonCornerRadius))
                    }
                }
            }

            Spacer()

            Button {
                store.addRule()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.iconDefault)
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
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
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
                            .font(.iconDefault)
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
                    .foregroundStyle(Color.textSecondary)
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
                .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.buttonCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: PanelMetrics.buttonCornerRadius)
                        .strokeBorder(Color.borderDefault, lineWidth: 1)
                )
            }

            // Tool-name glob: warn when an allow rule uses a non-MCP pattern, otherwise preview matches
            if rule.isToolNameGlob {
                if store.selectedListKind == .allow && !rule.isMCPToolNamePattern {
                    toolNameGlobWarning
                } else {
                    toolNamePatternPreview(rule)
                }
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
                .foregroundStyle(Color.textSecondary)

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
        .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.buttonCornerRadius))
    }

    // MARK: - Tool Name Glob

    private var toolNameGlobWarning: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.iconDefault)
                .foregroundStyle(Color.diffDeletion)
            Text("Claude Code rejects glob patterns in allow-rule tool names unless they target MCP tools (mcp__server__tool). Use a deny rule or an MCP-style pattern instead.")
                .font(.uiCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.buttonCornerRadius))
    }

    private func toolNamePatternPreview(_ rule: PermissionRule) -> some View {
        let samples = PermissionRule.toolNamePatternSamples(for: rule)
        return VStack(alignment: .leading, spacing: 3) {
            Text(rule.toolName == "*" ? "Matches all tools" : "Tool name pattern preview")
                .font(.uiCaption)
                .foregroundStyle(Color.textSecondary)

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
        .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.buttonCornerRadius))
    }

    // MARK: - User Deny Reference

    private var userDenyReferenceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("User deny (read-only)")
                    .font(.uiCaption)
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text("\(store.userDenyRules.count)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ForEach(store.userDenyRules) { rule in
                HStack(spacing: 8) {
                    Image(systemName: "lock")
                        .font(.system(size: 9, weight: .semibold))
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
                .foregroundStyle(Color.textSecondary)
            Text("No \(store.selectedListKind.rawValue.lowercased()) rules")
                .font(.uiCaption)
                .foregroundStyle(Color.textSecondary)
            Button {
                store.addRule()
            } label: {
                Text("Add Rule")
                    .font(.uiCaption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
