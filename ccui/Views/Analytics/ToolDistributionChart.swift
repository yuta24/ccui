import Charts
import SwiftUI

struct ToolDistributionChart: View {
    let points: [SessionAnalyticsPoint]

    private struct ToolEntry: Identifiable {
        let toolName: String
        let count: Int
        var id: String { toolName }
    }

    private var entries: [ToolEntry] {
        var totals: [String: Int] = [:]
        for point in points {
            for (name, count) in point.toolCounts {
                totals[name, default: 0] += count
            }
        }
        return totals
            .map { ToolEntry(toolName: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        Chart(entries) { entry in
            BarMark(
                x: .value("Count", entry.count),
                y: .value("Tool", entry.toolName)
            )
            .foregroundStyle(barColor(for: entry.toolName))
            .cornerRadius(2)
            .annotation(position: .trailing, alignment: .leading) {
                Text("\(entry.count)")
                    .font(.uiCaptionMono)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.uiCaptionMono)
                    .foregroundStyle(Color.textSecondary)
            }
        }
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
}
