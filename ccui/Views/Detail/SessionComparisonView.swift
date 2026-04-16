import SwiftUI

struct SessionComparisonView: View {
    let store: SessionComparisonStore

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { store.close() }

            if let evalA = store.evaluationA, let evalB = store.evaluationB {
                comparisonPanel(evalA: evalA, evalB: evalB)
            }
        }
    }

    // MARK: - Panel

    private func comparisonPanel(evalA: SessionEvaluation, evalB: SessionEvaluation) -> some View {
        VStack(spacing: 0) {
            panelHeader
            Rectangle().fill(Color.borderSubtle).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    autonomyComparison(evalA: evalA, evalB: evalB)
                    sectionDivider
                    summaryComparison(evalA: evalA, evalB: evalB)
                    sectionDivider
                    toolComparison(evalA: evalA, evalB: evalB)
                    sectionDivider
                    outcomeComparison(evalA: evalA, evalB: evalB)
                }
            }
        }
        .frame(maxWidth: 720, maxHeight: 560)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.borderDefault, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
    }

    private var sectionDivider: some View {
        Rectangle().fill(Color.borderSubtle).frame(height: 1)
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack {
            Text("Session Comparison")
                .font(.uiLabel)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Button { store.close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.hoverScale)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Autonomy

    private func autonomyComparison(evalA: SessionEvaluation, evalB: SessionEvaluation) -> some View {
        HStack(spacing: 0) {
            autonomyColumn(eval: evalA, title: store.titleA ?? "A")
            Rectangle().fill(Color.borderSubtle).frame(width: 1)
            autonomyColumn(eval: evalB, title: store.titleB ?? "B")
        }
        .padding(.vertical, 12)
    }

    private func autonomyColumn(eval: SessionEvaluation, title: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.uiCaptionMono)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
            Text(String(format: "%.0f%%", eval.autonomyScore * 100))
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundStyle(autonomyColor(eval.autonomyScore))
            Text("Autonomy")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func autonomyColor(_ score: Double) -> Color {
        if score >= 0.7 { return .statusClean }
        if score >= 0.4 { return .accent }
        return .diffDeletion
    }

    // MARK: - Summary

    private func summaryComparison(evalA: SessionEvaluation, evalB: SessionEvaluation) -> some View {
        HStack(spacing: 0) {
            summaryColumn(eval: evalA)
            Rectangle().fill(Color.borderSubtle).frame(width: 1)
            summaryColumn(eval: evalB)
        }
    }

    private func summaryColumn(eval: SessionEvaluation) -> some View {
        HStack(spacing: 16) {
            metricItem(value: "\(eval.eventCount)", label: "events")
            metricItem(value: eval.formattedDuration, label: "duration")
            metricItem(
                value: "\(eval.interventionCount)",
                label: "interventions",
                color: eval.interventionCount > 0 ? .interventionColor : nil
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func metricItem(value: String, label: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.uiLabel)
                .foregroundStyle(color ?? Color.textPrimary)
            Text(label)
                .font(.uiCaption)
                .foregroundStyle(color?.opacity(0.7) ?? Color.textTertiary)
        }
    }

    // MARK: - Tool Usage

    private func toolComparison(evalA: SessionEvaluation, evalB: SessionEvaluation) -> some View {
        let allTools = Set(evalA.toolStats.map(\.toolName) + evalB.toolStats.map(\.toolName))
            .sorted()
        let countsA = Dictionary(uniqueKeysWithValues: evalA.toolStats.map { ($0.toolName, $0.count) })
        let countsB = Dictionary(uniqueKeysWithValues: evalB.toolStats.map { ($0.toolName, $0.count) })
        let maxCount = max(
            evalA.toolStats.first?.count ?? 1,
            evalB.toolStats.first?.count ?? 1
        )

        return VStack(alignment: .leading, spacing: 4) {
            Text("TOOL USAGE")
                .sectionHeader()
                .padding(.horizontal, 16)
                .padding(.top, 10)

            ForEach(allTools, id: \.self) { tool in
                comparisonToolRow(
                    tool: tool,
                    countA: countsA[tool] ?? 0,
                    countB: countsB[tool] ?? 0,
                    maxCount: maxCount
                )
            }
            .padding(.bottom, 4)
        }
    }

    private func comparisonToolRow(tool: String, countA: Int, countB: Int, maxCount: Int) -> some View {
        HStack(spacing: 8) {
            Text(tool)
                .font(.uiCaptionMono)
                .foregroundStyle(Color.textSecondary)
                .frame(width: 80, alignment: .trailing)
                .lineLimit(1)

            HStack(spacing: 4) {
                GeometryReader { geo in
                    let widthA = maxCount > 0 ? max(countA > 0 ? 2 : 0, geo.size.width * CGFloat(countA) / CGFloat(maxCount)) : 0
                    let widthB = maxCount > 0 ? max(countB > 0 ? 2 : 0, geo.size.width * CGFloat(countB) / CGFloat(maxCount)) : 0
                    VStack(alignment: .leading, spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(for: tool))
                            .frame(width: widthA, height: 6)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(for: tool).opacity(0.5))
                            .frame(width: widthB, height: 6)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 18)
            }

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(countA)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)
                Text("\(countB)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(width: 28)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 1)
    }

    private func barColor(for toolName: String) -> Color {
        switch toolName {
        case "Read": .statusRenamed
        case "Edit", "Write": .accent
        case "Bash": .diffAddition
        case "Grep", "Glob": .statusRenamed.opacity(0.7)
        default: .textTertiary
        }
    }

    // MARK: - Outcome

    private func outcomeComparison(evalA: SessionEvaluation, evalB: SessionEvaluation) -> some View {
        HStack(spacing: 0) {
            outcomeColumn(eval: evalA)
            Rectangle().fill(Color.borderSubtle).frame(width: 1)
            outcomeColumn(eval: evalB)
        }
    }

    private func outcomeColumn(eval: SessionEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let outcome = eval.outcome {
                HStack(spacing: 6) {
                    Circle()
                        .fill(outcomeColor(outcome))
                        .frame(width: 8, height: 8)
                    Text(outcome.displayLabel)
                        .font(.uiLabel)
                        .foregroundStyle(Color.textPrimary)
                }
            } else {
                Text("No label")
                    .font(.uiCaption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func outcomeColor(_ outcome: SessionOutcome) -> Color {
        switch outcome {
        case .success: .statusClean
        case .failure: .diffDeletion
        case .partial: .accent
        }
    }
}
