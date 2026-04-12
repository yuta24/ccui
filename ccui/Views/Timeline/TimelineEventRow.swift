import SwiftUI

struct TimelineEventRow: View {
    let event: ClaudeEvent
    let previousEvent: ClaudeEvent?
    let isLast: Bool

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Time column
            Text(Self.timeFormatter.string(from: event.receivedAt))
                .font(.uiCaptionMono)
                .foregroundStyle(Color.textTertiary)
                .frame(width: 56, alignment: .trailing)

            // Timeline rail
            VStack(spacing: 0) {
                Rectangle()
                    .fill(previousEvent != nil ? Color.borderDefault : Color.clear)
                    .frame(width: 1, height: 6)
                Circle()
                    .fill(eventColor)
                    .frame(width: 7, height: 7)
                Rectangle()
                    .fill(isLast ? Color.clear : Color.borderDefault)
                    .frame(width: 1)
                    .frame(minHeight: 6)
            }
            .frame(width: 20)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: eventIcon)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(eventColor)
                    Text(eventLabel)
                        .font(.uiCaption)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }

                if let detail = eventDetail {
                    Text(detail)
                        .font(.uiCaptionMono)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(2)
                }

                if let elapsed = elapsedSincePrevious {
                    Text(elapsed)
                        .font(.uiCaptionMono)
                        .foregroundStyle(Color.textTertiary)
                        .opacity(0.6)
                }
            }
            .padding(.trailing, 12)
            .padding(.vertical, 4)
        }
        .padding(.leading, 4)
    }

    // MARK: - Event Properties

    private var eventColor: Color {
        switch event.hookEventName {
        case .preToolUse: .statusRenamed
        case .postToolUse: .accent
        case .stop, .subagentStop: .statusClean
        case .notification: .accent
        }
    }

    private var eventIcon: String {
        switch event.hookEventName {
        case .preToolUse: "hammer"
        case .postToolUse: "brain"
        case .stop: "checkmark.circle.fill"
        case .subagentStop: "checkmark.circle"
        case .notification: "bell.fill"
        }
    }

    private var eventLabel: String {
        switch event.hookEventName {
        case .preToolUse: event.toolName ?? "Tool"
        case .postToolUse: "Thinking"
        case .stop: "Done"
        case .subagentStop: "Subagent Done"
        case .notification: "Notification"
        }
    }

    private var eventDetail: String? {
        switch event.hookEventName {
        case .notification: event.message
        default: nil
        }
    }

    private var elapsedSincePrevious: String? {
        guard let prev = previousEvent else { return nil }
        let interval = event.receivedAt.timeIntervalSince(prev.receivedAt)
        guard interval >= 1.0 else { return nil }

        if interval < 60 {
            return "+\(String(format: "%.1f", interval))s"
        } else if interval < 3600 {
            let minutes = Int(interval) / 60
            let seconds = Int(interval) % 60
            return "+\(minutes)m\(seconds)s"
        } else {
            let hours = Int(interval) / 3600
            let minutes = (Int(interval) % 3600) / 60
            return "+\(hours)h\(minutes)m"
        }
    }
}
