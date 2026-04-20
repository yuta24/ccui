import SwiftUI

struct TimelineView: View {
    let worktreePath: String
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @State private var cachedEvents: [ClaudeEvent] = []
    @State private var cachedInterventionIds: Set<UUID> = []
    @State private var hasTruncatedSessions: Bool = false

    var body: some View {
        let events = cachedEvents
        let interventionIds = cachedInterventionIds
        VStack(alignment: .leading, spacing: 0) {
            header(eventCount: events.count, interventionCount: interventionIds.count)
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            if hasTruncatedSessions {
                truncatedBanner
            }

            if events.isEmpty {
                emptyState
            } else {
                eventList(events, interventionIds: interventionIds)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.surfacePrimary)
        .onAppear { recomputeCache() }
        .onChange(of: worktreePath) { _, _ in
            recomputeCache()
        }
        .onChange(of: claudeEventStore.sessions[worktreePath]) { _, _ in
            recomputeCache()
        }
    }

    // MARK: - Header

    private func header(eventCount: Int, interventionCount: Int) -> some View {
        HStack {
            Text("Timeline")
                .sectionHeader()
            Spacer()
            if interventionCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.interventionColor)
                    Text("\(interventionCount)")
                        .font(.uiCaption)
                        .foregroundStyle(Color.interventionColor)
                }
            }
            Text("\(eventCount)")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Truncated Banner

    private var truncatedBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.orange)
            Text("Older events were dropped (limit: \(claudeEventStore.maxEventsPerSessionLimit)). Metrics may be inaccurate.")
                .font(.uiCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 24))
                .foregroundStyle(Color.textTertiary)
            Text("No events yet")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
            Text("Agent activity will appear here")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
                .opacity(0.6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Event List

    private func eventList(_ events: [ClaudeEvent], interventionIds: Set<UUID>) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        TimelineEventRow(
                            event: event,
                            previousEvent: index > 0 ? events[index - 1] : nil,
                            isLast: index == events.count - 1,
                            isIntervention: interventionIds.contains(event.id)
                        )
                        .id(event.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: events.last?.id) { _, newId in
                if let id = newId {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func recomputeCache() {
        let worktreeSessions = claudeEventStore.sessions[worktreePath] ?? [:]
        let events = worktreeSessions.values
            .flatMap(\.events)
            .sorted(by: { $0.receivedAt < $1.receivedAt })
        cachedEvents = events
        cachedInterventionIds = Set(InterventionDetector.interventions(in: events).map(\.id))
        hasTruncatedSessions = worktreeSessions.values.contains(where: \.isTruncated)
    }
}
