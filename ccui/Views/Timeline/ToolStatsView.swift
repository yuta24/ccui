import SwiftUI

struct ToolStatsView: View {
    let repositoryPath: String
    @State private var toolStatsStore = ToolStatsStore()
    @State private var scope: Scope = .repository

    enum Scope: String, CaseIterable {
        case repository = "Repository"
        case all = "All"
    }

    private var effectiveRepositoryPath: String? {
        scope == .repository ? repositoryPath : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            if toolStatsStore.isLoading {
                loadingState
            } else if toolStatsStore.snapshot.stats.isEmpty {
                emptyState
            } else {
                statsContent
            }
        }
        .frame(width: 280)
        .background(Color.surfacePrimary)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.borderSubtle).frame(width: 1)
        }
        .onAppear {
            toolStatsStore.loadStats(repositoryPath: effectiveRepositoryPath)
        }
        .onChange(of: scope) { _, _ in
            toolStatsStore.loadStats(repositoryPath: effectiveRepositoryPath)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Tool Stats")
                    .sectionHeader()
                Spacer()
                Button {
                    toolStatsStore.loadStats(repositoryPath: effectiveRepositoryPath)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.hoverScale)
            }
            Picker("", selection: $scope) {
                ForEach(Scope.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.mini)
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
            Text("No tool usage data")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Content

    private var statsContent: some View {
        let snapshot = toolStatsStore.snapshot
        let maxCount = snapshot.stats.first?.count ?? 1

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Summary
                HStack(spacing: 16) {
                    summaryItem(value: "\(snapshot.sessionCount)", label: "sessions")
                    summaryItem(value: "\(snapshot.totalEvents)", label: "events")
                    summaryItem(value: "\(snapshot.stats.count)", label: "tools")
                    if snapshot.interventionCount > 0 {
                        summaryItem(value: "\(snapshot.interventionCount)", label: "interventions", color: .interventionColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Rectangle()
                    .fill(Color.borderSubtle)
                    .frame(height: 1)

                // Bar chart
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(snapshot.stats) { stat in
                        toolBar(stat: stat, maxCount: maxCount)
                    }
                }
                .padding(.vertical, 4)
            }
        }
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
                    .fill(barColor(for: stat.toolName))
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
