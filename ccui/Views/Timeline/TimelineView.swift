import SwiftUI

struct TimelineView: View {
    let worktreePath: String
    @Environment(ClaudeEventStore.self) private var claudeEventStore

    private var sortedEvents: [ClaudeEvent] {
        let worktreeSessions = claudeEventStore.sessions[worktreePath] ?? [:]
        return worktreeSessions.values
            .flatMap(\.events)
            .sorted(by: { $0.receivedAt < $1.receivedAt })
    }

    var body: some View {
        let events = sortedEvents
        VStack(alignment: .leading, spacing: 0) {
            header(eventCount: events.count)
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            if events.isEmpty {
                emptyState
            } else {
                eventList(events)
            }
        }
        .frame(width: 280)
        .background(Color.surfacePrimary)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.borderSubtle).frame(width: 1)
        }
    }

    // MARK: - Header

    private func header(eventCount: Int) -> some View {
        HStack {
            Text("Timeline")
                .sectionHeader()
            Spacer()
            Text("\(eventCount)")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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

    private func eventList(_ events: [ClaudeEvent]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        TimelineEventRow(
                            event: event,
                            previousEvent: index > 0 ? events[index - 1] : nil,
                            isLast: index == events.count - 1
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
}
