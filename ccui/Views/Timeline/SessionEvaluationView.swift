import SwiftUI

struct SessionEvaluationView: View {
    let store: SessionEvaluationStore
    @Binding var isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            if let eval = store.evaluation {
                evaluationContent(eval)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.surfacePrimary)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Evaluation")
                .sectionHeader()
            Spacer()
            if let title = store.sessionTitle {
                Text(title)
                    .font(.uiCaptionMono)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }
            Button {
                store.close()
                isVisible = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 24))
                .foregroundStyle(Color.textTertiary)
            Text("Select a session to evaluate")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Content

    private func evaluationContent(_ eval: SessionEvaluation) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if store.isTruncated {
                    truncatedBanner
                    divider
                }
                autonomySection(eval)
                divider
                summarySection(eval)
                divider
                toolSection(eval)
                if !eval.interventionsByTool.isEmpty {
                    divider
                    interventionSection(eval)
                }
                if eval.outcome != nil || !eval.failureReasons.isEmpty {
                    divider
                    outcomeSection(eval)
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(height: 1)
    }

    // MARK: - Truncated Banner

    private var truncatedBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color.statusWarning)
            Text("Older events were dropped. Scores may be inaccurate.")
                .font(.uiCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.statusWarningBg)
    }

    // MARK: - Autonomy Score

    private func autonomySection(_ eval: SessionEvaluation) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f%%", eval.autonomyScore * 100))
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .foregroundStyle(autonomyColor(eval.autonomyScore))
            Text("Autonomy")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func autonomyColor(_ score: Double) -> Color {
        score >= 0.7 ? .statusClean : score >= 0.4 ? .accent : .diffDeletion
    }

    // MARK: - Summary

    private func summarySection(_ eval: SessionEvaluation) -> some View {
        HStack(spacing: 16) {
            summaryItem(value: "\(eval.eventCount)", label: "events")
            summaryItem(value: eval.formattedDuration, label: "duration")
            summaryItem(value: "\(eval.interventionCount)", label: "interventions",
                        color: eval.interventionCount > 0 ? .interventionColor : nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func summaryItem(value: String, label: String, color: Color? = nil) -> some View {
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

    private func toolSection(_ eval: SessionEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TOOL USAGE")
                .sectionHeader()
                .padding(.horizontal, 12)
                .padding(.top, 10)

            let maxCount = eval.toolStats.first?.count ?? 1
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(eval.toolStats) { stat in
                    toolBar(stat: stat, maxCount: maxCount)
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func toolBar(stat: ToolUsageStat, maxCount: Int) -> some View {
        HStack(spacing: 8) {
            Text(stat.toolName)
                .font(.uiCaptionMono)
                .foregroundStyle(Color.textSecondary)
                .frame(width: 80, alignment: .trailing)
                .lineLimit(1)

            GeometryReader { geo in
                let barWidth = max(2, geo.size.width * CGFloat(stat.count) / CGFloat(maxCount))
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.toolBarColor(for: stat.toolName))
                    .frame(width: barWidth, height: 14)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 18)

            Text("\(stat.count)")
                .font(.uiCaptionMono)
                .foregroundStyle(Color.textTertiary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    // MARK: - Interventions by Tool

    private func interventionSection(_ eval: SessionEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("INTERVENTIONS")
                .sectionHeader()
                .padding(.horizontal, 12)
                .padding(.top, 10)

            let sorted = eval.interventionsByTool.sorted { $0.value > $1.value }
            ForEach(sorted, id: \.key) { key, count in
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.interventionColor)
                    Text(key)
                        .font(.uiCaptionMono)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text("\(count)")
                        .font(.uiCaptionMono)
                        .foregroundStyle(Color.interventionColor)
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Outcome

    private func outcomeSection(_ eval: SessionEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RESULT")
                .sectionHeader()
                .padding(.horizontal, 12)
                .padding(.top, 10)

            if let outcome = eval.outcome {
                HStack(spacing: 6) {
                    Circle()
                        .fill(outcome.color)
                        .frame(width: 8, height: 8)
                    Text(outcome.displayLabel)
                        .font(.uiLabel)
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, 12)
            }

            if !eval.failureReasons.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(eval.failureReasons).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { reason in
                        Text(reason.displayLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.surfaceElevated)
                            )
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.bottom, 10)
    }
}
