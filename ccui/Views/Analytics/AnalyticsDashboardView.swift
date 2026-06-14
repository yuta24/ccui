import SwiftUI

struct AnalyticsDashboardView: View {
    let store: SessionAnalyticsStore
    let repositoryPath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            if store.isLoading {
                loadingState
            } else if store.points.isEmpty {
                emptyState
            } else {
                dashboardContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.surfacePrimary)
        .onAppear { store.load(repositoryPath: repositoryPath) }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Analytics")
                .sectionHeader()
            Spacer()
            Button {
                store.load(repositoryPath: repositoryPath)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.hoverScale)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack {
            Spacer()
            PulsingDotsView()
                .padding(.bottom, 8)
            Text("Loading...")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "chart.bar")
                .font(.system(size: 24))
                .foregroundStyle(Color.textTertiary)
            Text("No session data")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Dashboard Content

    private var dashboardContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                summaryStrip

                chartSection(title: "AUTONOMY OVER TIME") {
                    AutonomyScoreChart(points: store.points)
                        .frame(height: 140)
                }

                chartSection(title: "PERMISSION INTERVENTIONS") {
                    InterventionFrequencyChart(points: store.points)
                        .frame(height: 120)
                }

                chartSection(title: "TOOL USAGE") {
                    ToolDistributionChart(points: store.points)
                        .frame(height: toolChartHeight)
                }

                chartSection(title: "USAGE BY CATEGORY") {
                    ToolCategoryBreakdownChart(points: store.points)
                        .frame(height: categoryChartHeight)
                }

                chartSection(title: "SESSION DURATION") {
                    SessionDurationChart(points: store.points)
                        .frame(height: 120)
                }
            }
        }
    }

    private var toolChartHeight: CGFloat {
        max(80, CGFloat(store.uniqueToolCount) * 26)
    }

    private var categoryChartHeight: CGFloat {
        var categories: Set<ToolCategory> = []
        for point in store.points {
            for toolName in point.toolCounts.keys {
                categories.insert(ToolCategory.categorize(toolName: toolName))
            }
        }
        return max(60, CGFloat(categories.count) * 26)
    }

    private var summaryStrip: some View {
        let sessionCount = store.points.count
        let totalInterventions = store.points.reduce(0) { $0 + $1.interventionCount }
        let averageAutonomy = sessionCount > 0
            ? store.points.reduce(0.0) { $0 + $1.autonomyScore } / Double(sessionCount)
            : 0

        return HStack(spacing: 16) {
            summaryItem(value: "\(sessionCount)", label: "sessions")
            summaryItem(
                value: String(format: "%.0f%%", averageAutonomy * 100),
                label: "avg autonomy"
            )
            if totalInterventions > 0 {
                summaryItem(
                    value: "\(totalInterventions)",
                    label: "interventions",
                    color: .interventionColor
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func summaryItem(value: String, label: LocalizedStringKey, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.uiLabel)
                .foregroundStyle(color ?? Color.textPrimary)
            Text(label)
                .font(.uiCaption)
                .foregroundStyle(color?.opacity(0.7) ?? Color.textTertiary)
        }
    }

    @ViewBuilder
    private func chartSection<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(height: 1)

        Text(title)
            .sectionHeader()
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

        content()
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
    }
}
