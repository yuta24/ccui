import Charts
import SwiftUI

struct SessionDurationChart: View {
    let points: [SessionAnalyticsPoint]

    private var entries: [SessionAnalyticsPoint] {
        points.filter { $0.duration != nil }
    }

    var body: some View {
        Chart(entries) { point in
            BarMark(
                x: .value("Session", point.sessionStart),
                y: .value("Duration", (point.duration ?? 0) / 60.0)
            )
            .foregroundStyle(Color.accent.opacity(0.7))
            .cornerRadius(2)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Color.borderSubtle)
                AxisValueLabel {
                    if let n = value.as(Double.self) {
                        Text(formatMinutes(n))
                            .font(.uiCaptionMono)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
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

    private func formatMinutes(_ minutes: Double) -> String {
        if minutes < 1 { return "\(Int(minutes * 60))s" }
        if minutes < 60 { return "\(Int(minutes))m" }
        let h = Int(minutes / 60)
        let m = Int(minutes.truncatingRemainder(dividingBy: 60))
        return "\(h)h \(m)m"
    }
}
