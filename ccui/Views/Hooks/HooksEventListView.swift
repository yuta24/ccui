import SwiftUI

struct HooksEventListView: View {
    @Bindable var store: HooksStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(HooksStore.allEvents, id: \.rawValue) { event in
                eventRow(event)
                if event != HooksStore.allEvents.last {
                    Rectangle()
                        .fill(Color.borderSubtle)
                        .frame(height: 1)
                }
            }
        }
    }

    private func eventRow(_ event: ClaudeHookPayload.HookEventName) -> some View {
        let isSelected = store.selectedEventName == event
        let entries = store.entries[event] ?? []
        let userCount = entries.filter { !$0.isManagedByCCUI }.count
        let fireCount = store.fireLogs.filter { $0.eventName == event }.count

        return Button {
            store.selectedEventName = event
            store.selectedEntryID = nil
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconName(for: event))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accent : Color.textSecondary)
                    .frame(width: 14)

                Text(event.rawValue)
                    .font(.uiCaption)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.primary)

                Spacer()

                if fireCount > 0 {
                    Text("\(fireCount)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                if userCount > 0 {
                    Text("\(userCount)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(isSelected ? Color.surfaceHover : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func iconName(for event: ClaudeHookPayload.HookEventName) -> String {
        switch event {
        case .preToolUse: "arrow.right.circle"
        case .postToolUse: "arrow.left.circle"
        case .stop: "stop.circle"
        case .notification: "bell"
        case .subagentStop: "person.2"
        case .permissionRequest: "lock.shield"
        case .userPromptSubmit: "text.bubble"
        case .sessionStart: "play.circle"
        case .messageDisplay: "message"
        }
    }
}
