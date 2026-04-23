import Charts
import SwiftUI

struct InterventionFrequencyChart: View {
    let points: [SessionAnalyticsPoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Session", point.sessionStart),
                y: .value("Interventions", point.interventionCount)
            )
            .foregroundStyle(Color.interventionColor)
            .cornerRadius(2)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.borderSubtle)
                AxisValueLabel()
                    .font(.uiCaptionMono)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.borderSubtle)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.uiCaptionMono)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }
}
