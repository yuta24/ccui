import SwiftUI

struct TimelineEventRow: View {
    let event: ClaudeEvent
    let previousEvent: ClaudeEvent?
    let toolDuration: TimeInterval?
    let isLast: Bool
    let isIntervention: Bool

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
                        .font(.iconSmall)
                        .foregroundStyle(eventColor)
                    Text(eventLabel)
                        .font(.uiCaption)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    if let duration = toolDuration {
                        Spacer()
                        toolDurationView(duration)
                    }
                }

                if let detail = eventDetail {
                    Text(detail)
                        .font(.uiCaptionMono)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                }

                if let elapsed = elapsedSincePrevious {
                    Text(elapsed)
                        .font(.uiCaptionMono)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.trailing, 12)
            .padding(.vertical, 4)
        }
        .padding(.leading, 4)
    }

    // MARK: - Event Properties

    private var eventColor: Color {
        if isIntervention { return .interventionColor }
        return switch event.hookEventName {
        case .preToolUse: .statusRenamed
        case .postToolUse: .accent
        case .stop, .subagentStop: .statusClean
        case .notification: .accent
        case .permissionRequest: .interventionColor
        case .userPromptSubmit: .interventionColor
        case .sessionStart: .statusClean
        case .messageDisplay: .accent
        }
    }

    private var eventIcon: String {
        if isIntervention { return "person.fill.questionmark" }
        return switch event.hookEventName {
        case .preToolUse: "hammer"
        case .postToolUse: "brain"
        case .stop: "checkmark.circle.fill"
        case .subagentStop: "checkmark.circle"
        case .notification: "bell.fill"
        case .permissionRequest: "lock.shield"
        case .userPromptSubmit: "text.bubble"
        case .sessionStart: "play.circle"
        case .messageDisplay: "message"
        }
    }

    private var eventLabel: String {
        if isIntervention {
            return switch event.hookEventName {
            case .permissionRequest: "Permission Request"
            case .userPromptSubmit: "User Prompt"
            case .preToolUse: "User Input"
            default: "Intervention"
            }
        }
        return switch event.hookEventName {
        case .preToolUse: event.toolName ?? "Tool"
        case .postToolUse: "Thinking"
        case .stop: "Done"
        case .subagentStop: "Subagent Done"
        case .notification: "Notification"
        case .permissionRequest: "Permission Request"
        case .userPromptSubmit: "User Prompt"
        case .sessionStart: "Session Start"
        case .messageDisplay: "Message"
        }
    }

    private var eventDetail: String? {
        switch event.hookEventName {
        case .notification: event.message
        case .permissionRequest: event.toolName
        case .messageDisplay: event.delta
        default: nil
        }
    }

    private func toolDurationView(_ duration: TimeInterval) -> some View {
        // Log scale: 1s ≈ 12%, 10s ≈ 42%, 60s ≈ 72%, 300s = 100%
        let logFraction = log(duration + 1) / log(301)
        let barWidth = max(4, CGFloat(min(logFraction, 1.0)) * 48)
        let color = durationColor(duration)
        return HStack(spacing: 4) {
            Capsule()
                .fill(color.opacity(0.5))
                .frame(width: barWidth, height: 2)
            Text(Self.formatInterval(duration))
                .font(.uiCaptionMono)
                .foregroundStyle(color)
        }
    }

    private func durationColor(_ duration: TimeInterval) -> Color {
        if duration < 3 { return .statusClean }
        if duration < 15 { return .accent }
        return .statusWarning
    }

    // Shared interval formatter — used by toolDurationView and elapsedSincePrevious.
    private static func formatInterval(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return String(format: "%.1fs", interval)
        } else if interval < 3600 {
            let minutes = Int(interval) / 60
            let seconds = Int(interval) % 60
            return "\(minutes)m\(seconds)s"
        } else {
            let hours = Int(interval) / 3600
            let minutes = (Int(interval) % 3600) / 60
            return "\(hours)h\(minutes)m"
        }
    }

    private var elapsedSincePrevious: String? {
        guard let prev = previousEvent else { return nil }
        let interval = event.receivedAt.timeIntervalSince(prev.receivedAt)
        guard interval >= 1.0 else { return nil }
        return "+" + Self.formatInterval(interval)
    }
}
