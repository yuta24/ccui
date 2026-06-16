import SwiftUI

struct SessionAnnotationRow: View {
    let entry: WorktreeSessionEntry
    let worktreePath: String
    var isRunning: Bool = false
    let onResume: () -> Void
    let onDelete: () -> Void
    let onEvaluate: () -> Void

    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @State private var showAnnotationPopover = false
    @State private var isHovered = false

    private var session: AgentSession? {
        claudeEventStore.sessions[worktreePath]?[entry.sessionId]
    }

    var body: some View {
        Button(action: onResume) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isRunning {
                        Circle()
                            .fill(Color.statusClean)
                            .frame(width: 6, height: 6)
                    }
                    Text(entry.title ?? String(entry.sessionId.prefix(8)))
                        .font(.uiLabel)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    if let outcome = session?.outcome {
                        outcomeBadge(outcome)
                    }
                    Text(entry.createdAt, style: .offset)
                        .font(.uiCaption)
                        .foregroundStyle(Color.textSecondary)
                    if let count = session?.interventionCount, count > 0 {
                        Text("\u{00B7}")
                            .foregroundStyle(Color.textSecondary)
                        HStack(spacing: 2) {
                            Image(systemName: "person.fill.questionmark")
                                .font(.system(size: 8))
                            Text("\(count)")
                                .font(.uiCaption)
                        }
                        .foregroundStyle(Color.interventionColor)
                    }
                    if session?.isTruncated == true {
                        Text("\u{00B7}")
                            .foregroundStyle(Color.textSecondary)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.statusWarning)
                            .help("Older events were dropped. Metrics are minimums.")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .overlay(alignment: .trailing) {
                if isHovered || showAnnotationPopover {
                    HStack(spacing: 0) {
                        if session != nil {
                            Button {
                                showAnnotationPopover.toggle()
                            } label: {
                                Image(systemName: "tag")
                                    .font(.system(size: 11))
                                    .foregroundStyle(session?.outcome != nil ? Color.accent : Color.textSecondary)
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.hoverScale)
                            .popover(isPresented: $showAnnotationPopover, arrowEdge: .trailing) {
                                annotationPopover
                            }
                        }
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accent)
                            .frame(width: 28, height: 28)
                    }
                    .padding(.trailing, 8)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.surfaceHover.opacity(0),
                                Color.surfaceHover,
                            ],
                            startPoint: .leading,
                            endPoint: .init(x: 0.3, y: 0.5)
                        )
                        .opacity(isHovered || showAnnotationPopover ? 1 : 0)
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .background(isHovered || showAnnotationPopover ? Color.surfaceHover : Color.clear)
        .onHover { hovering in isHovered = hovering }
        .contextMenu {
            if session != nil {
                Button { onEvaluate() } label: {
                    Label("Evaluate", systemImage: "checkmark.seal")
                }
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Outcome Badge

    private func outcomeBadge(_ outcome: SessionOutcome) -> some View {
        Text(outcome.displayLabel)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(outcome.color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(outcome.color.opacity(0.15))
            )
    }

    // MARK: - Annotation Popover

    private var annotationPopover: some View {
        let currentOutcome = session?.outcome
        let currentReasons = session?.failureReasons ?? []

        return VStack(alignment: .leading, spacing: 12) {
            Text("Annotation")
                .font(.uiLabel)
                .foregroundStyle(Color.textPrimary)

            // Outcome picker
            VStack(alignment: .leading, spacing: 6) {
                Text("OUTCOME")
                    .sectionHeader()
                HStack(spacing: 6) {
                    outcomeButton(nil, label: "None", current: currentOutcome)
                    ForEach(SessionOutcome.allCases, id: \.self) { outcome in
                        outcomeButton(outcome, label: outcome.displayLabel, current: currentOutcome)
                    }
                }
            }

            // Failure reasons (shown for failure or partial)
            if currentOutcome == .failure || currentOutcome == .partial {
                VStack(alignment: .leading, spacing: 6) {
                    Text("REASONS")
                        .sectionHeader()
                    FlowLayout(spacing: 4) {
                        ForEach(FailureReason.allCases, id: \.self) { reason in
                            reasonToggle(reason, isSelected: currentReasons.contains(reason))
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    private func outcomeButton(_ outcome: SessionOutcome?, label: String, current: SessionOutcome?) -> some View {
        let isSelected = outcome == current
        return Button {
            var reasons = session?.failureReasons ?? []
            if outcome == .success || outcome == nil {
                reasons = []
            }
            claudeEventStore.annotateSession(
                worktreePath: worktreePath,
                sessionId: entry.sessionId,
                outcome: outcome,
                failureReasons: reasons
            )
        } label: {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.textInverted : Color.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.textPrimary : Color.surfaceElevated)
                )
        }
        .buttonStyle(.plain)
    }

    private func reasonToggle(_ reason: FailureReason, isSelected: Bool) -> some View {
        Button {
            var reasons = session?.failureReasons ?? []
            if isSelected {
                reasons.remove(reason)
            } else {
                reasons.insert(reason)
            }
            claudeEventStore.annotateSession(
                worktreePath: worktreePath,
                sessionId: entry.sessionId,
                outcome: session?.outcome,
                failureReasons: reasons
            )
        } label: {
            Text(reason.displayLabel)
                .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Color.interventionColor : Color.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isSelected ? Color.interventionSubtle : Color.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(isSelected ? Color.interventionColor.opacity(0.3) : Color.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            )
            subview.place(at: point, anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
