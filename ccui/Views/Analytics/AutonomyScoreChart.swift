import Charts
import SwiftUI

struct AutonomyScoreChart: View {
    let points: [SessionAnalyticsPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Session", point.sessionStart),
                y: .value("Autonomy", point.autonomyScore)
            )
            .foregroundStyle(Color.accent.opacity(0.4))
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Session", point.sessionStart),
                y: .value("Autonomy", point.autonomyScore)
            )
            .foregroundStyle(autonomyColor(point.autonomyScore))
            .symbolSize(36)
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(values: [0, 0.5, 1.0]) { value in
                AxisGridLine().foregroundStyle(Color.borderSubtle)
                AxisValueLabel {
                    if let n = value.as(Double.self) {
                        Text(String(format: "%.0f%%", n * 100))
                            .font(.uiCaptionMono)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.borderSubtle)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.uiCaptionMono)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    private func autonomyColor(_ score: Double) -> Color {
        if score >= 0.8 { return .statusClean }
        if score >= 0.5 { return .accent }
        return .diffDeletion
    }
}
