import Charts
import SwiftUI

struct ToolCategoryBreakdownChart: View {
    let points: [SessionAnalyticsPoint]

    private struct CategoryEntry: Identifiable {
        let category: ToolCategory
        let count: Int
        var id: String { category.displayName }
    }

    private var entries: [CategoryEntry] {
        var totals: [ToolCategory: Int] = [:]
        for point in points {
            for (name, count) in point.toolCounts {
                totals[ToolCategory.categorize(toolName: name), default: 0] += count
            }
        }
        return totals
            .map { CategoryEntry(category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        Chart(entries) { entry in
            BarMark(
                x: .value("Count", entry.count),
                y: .value("Category", entry.category.displayName)
            )
            .foregroundStyle(barColor(for: entry.category))
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

    private func barColor(for category: ToolCategory) -> Color {
        switch category {
        case .builtin: .statusRenamed
        case .subagent: .accent
        case .mcp: .diffAddition
        }
    }
}
