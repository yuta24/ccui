import Foundation
import Testing
@testable import ccui

struct AgentSessionTests {

    // MARK: - append

    @Test func appendWithinLimit() {
        var session = TestHelpers.makeSession()
        let event = TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash")
        session.append(event, maxEvents: 100)
        #expect(session.events.count == 1)
        #expect(session.isTruncated == false)
    }

    @Test func appendExceedingLimitTruncates() {
        var session = TestHelpers.makeSession()
        for i in 0..<5 {
            session.append(
                TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Tool\(i)"),
                maxEvents: 3
            )
        }
        #expect(session.events.count == 3)
        #expect(session.isTruncated == true)
        // First events were evicted, last 3 remain
        #expect(session.events[0].toolName == "Tool2")
    }

    // MARK: - snapshot: activity

    private let activeTimeout: TimeInterval = 5 * 60
    private let attentionTimeout: TimeInterval = 60 * 60

    private func snapshot(
        _ session: AgentSession,
        now: Date = Date(),
        acknowledgedUpTo: Date? = nil
    ) -> SessionStateSnapshot {
        session.snapshot(now: now, acknowledgedUpTo: acknowledgedUpTo, activeTimeout: activeTimeout, attentionTimeout: attentionTimeout)
    }

    @Test func activityFromEmptyEventsIsIdle() {
        let session = TestHelpers.makeSession()
        #expect(snapshot(session).activity == .idle)
    }

    @Test func activityFromLastEvent() {
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash"),
            TestHelpers.makeEvent(hookEventName: .stop),
        ])
        #expect(snapshot(session).activity == .finished)
    }

    @Test func activityMapsPreToolUseToRunningTool() {
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash"),
        ])
        #expect(snapshot(session).activity == .runningTool("Bash"))
    }

    @Test func activityMapsNotificationToWaitingForUser() {
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .notification, message: "approve?"),
        ])
        #expect(snapshot(session).activity == .waitingForUser)
    }

    @Test func activityMapsPermissionRequestToWaitingForUser() {
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .permissionRequest, toolName: "Write"),
        ])
        #expect(snapshot(session).activity == .waitingForUser)
    }

    @Test func activityBecomesUnresponsiveWhenStaleBeyondActiveTimeout() {
        let base = Date()
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash", receivedAt: base),
        ])
        let result = snapshot(session, now: base.addingTimeInterval(activeTimeout + 1))
        #expect(result.activity == .unresponsive)
    }

    @Test func activityStaysActiveWithinActiveTimeout() {
        let base = Date()
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash", receivedAt: base),
        ])
        let result = snapshot(session, now: base.addingTimeInterval(activeTimeout - 1))
        #expect(result.activity == .runningTool("Bash"))
    }

    @Test func finishedAndIdleDoNotBecomeUnresponsiveWhenStale() {
        let base = Date()
        let finished = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .stop, receivedAt: base),
        ])
        let result = snapshot(finished, now: base.addingTimeInterval(activeTimeout * 10))
        #expect(result.activity == .finished)
    }

    // MARK: - snapshot: attention

    @Test func attentionIsNilWithoutNotificationOrPermissionRequest() {
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash"),
        ])
        #expect(snapshot(session).attention == nil)
    }

    @Test func attentionPersistsAfterActivityMovesOn() {
        // 通知の後にエージェントが活動を再開しても、attention は events.last に依存せず残り続ける
        let base = Date()
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .notification, message: "approve?", receivedAt: base),
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash", receivedAt: base.addingTimeInterval(1)),
        ])
        let result = snapshot(session, now: base.addingTimeInterval(2))
        #expect(result.activity == .runningTool("Bash"))
        #expect(result.attention?.reason == .notification(message: "approve?"))
    }

    @Test func attentionIsIgnoredWhenOlderThanAttentionTimeout() {
        let base = Date()
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .notification, message: "stale", receivedAt: base),
        ])
        let result = snapshot(session, now: base.addingTimeInterval(attentionTimeout + 1))
        #expect(result.attention == nil)
    }

    @Test func attentionIsAcknowledgedWhenOccurredBeforeCutoff() {
        let base = Date()
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .notification, message: "approve?", receivedAt: base),
        ])
        let result = snapshot(session, now: base.addingTimeInterval(10), acknowledgedUpTo: base.addingTimeInterval(5))
        #expect(result.attention?.isAcknowledged == true)
    }

    @Test func attentionIsUnacknowledgedWhenOccurredAfterCutoff() {
        let base = Date()
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .notification, message: "approve?", receivedAt: base),
        ])
        let result = snapshot(session, now: base.addingTimeInterval(10), acknowledgedUpTo: base.addingTimeInterval(-5))
        #expect(result.attention?.isAcknowledged == false)
    }

    // MARK: - isTerminal

    @Test func isTerminalForFinished() {
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .stop),
        ])
        #expect(session.isTerminal(now: Date(), activeTimeout: activeTimeout) == true)
    }

    @Test func isTerminalForThinking() {
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .postToolUse),
        ])
        #expect(session.isTerminal(now: Date(), activeTimeout: activeTimeout) == false)
    }

    @Test func isTerminalForWaitingForUser() {
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .permissionRequest, toolName: "Write"),
        ])
        #expect(session.isTerminal(now: Date(), activeTimeout: activeTimeout) == false)
    }

    @Test func isTerminalForToolUse() {
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash"),
        ])
        #expect(session.isTerminal(now: Date(), activeTimeout: activeTimeout) == false)
    }

    @Test func isTerminalForUnresponsive() {
        let base = Date()
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash", receivedAt: base),
        ])
        #expect(session.isTerminal(now: base.addingTimeInterval(activeTimeout + 1), activeTimeout: activeTimeout) == true)
    }

    // MARK: - lastEventAt

    @Test func lastEventAtReturnsLastDate() {
        let date = Date(timeIntervalSince1970: 1000)
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(receivedAt: Date(timeIntervalSince1970: 500)),
            TestHelpers.makeEvent(receivedAt: date),
        ])
        #expect(session.lastEventAt == date)
    }

    @Test func lastEventAtNilForEmpty() {
        let session = TestHelpers.makeSession()
        #expect(session.lastEventAt == nil)
    }

    // MARK: - interventionCount

    @Test func interventionCountMatchesDetector() {
        let session = TestHelpers.makeSession(events: [
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "Bash"),
            TestHelpers.makeEvent(hookEventName: .permissionRequest, toolName: "Write"),
            TestHelpers.makeEvent(hookEventName: .preToolUse, toolName: "AskUserQuestion"),
        ])
        #expect(session.interventionCount == 2)
    }

    // MARK: - setAnnotation

    @Test func setAnnotation() {
        var session = TestHelpers.makeSession()
        #expect(session.outcome == nil)
        #expect(session.failureReasons.isEmpty)

        session.setAnnotation(outcome: .failure, failureReasons: [.hallucination, .instructionGap])
        #expect(session.outcome == .failure)
        #expect(session.failureReasons.count == 2)
        #expect(session.failureReasons.contains(.hallucination))
    }
}

// MARK: - FileNode Tests

struct FileNodeTests {

    @Test func fileIsAlwaysLoaded() {
        let node = FileNode(name: "file.swift", path: "/file.swift", isDirectory: false, isLoaded: false)
        #expect(node.isLoaded == true)
    }

    @Test func directoryRespectsIsLoaded() {
        let unloaded = FileNode(name: "dir", path: "/dir", isDirectory: true, isLoaded: false)
        #expect(unloaded.isLoaded == false)

        let loaded = FileNode(name: "dir", path: "/dir", isDirectory: true, isLoaded: true)
        #expect(loaded.isLoaded == true)
    }

    @Test func withChildrenSetsLoadedTrue() {
        let dir = FileNode(name: "dir", path: "/dir", isDirectory: true, isLoaded: false)
        let child = FileNode(name: "a.swift", path: "/dir/a.swift", isDirectory: false)
        let updated = dir.withChildren([child])

        #expect(updated.isLoaded == true)
        #expect(updated.children.count == 1)
        #expect(updated.children[0].name == "a.swift")
        #expect(updated.id == dir.id) // preserves identity
    }

    @Test func withChildrenPreservesAttributes() {
        let dir = FileNode(name: "dir", path: "/dir", isDirectory: true, gitIgnoreStatus: .ignored)
        let updated = dir.withChildren([])
        #expect(updated.gitIgnoreStatus == .ignored)
        #expect(updated.name == "dir")
        #expect(updated.path == "/dir")
    }
}

// MARK: - Worktree Tests

struct WorktreeTests {

    @Test func displayNameUsesBranch() {
        let wt = Worktree(repositoryID: UUID(), path: "/repo/worktree", branch: "feature/test", isMain: false)
        #expect(wt.displayName == "feature/test")
    }

    @Test func displayNameFallsBackToDirectoryName() {
        let wt = Worktree(repositoryID: UUID(), path: "/repo/my-worktree", branch: nil, isMain: false)
        #expect(wt.displayName == "my-worktree")
    }

    @Test func idIsPath() {
        let wt = Worktree(repositoryID: UUID(), path: "/repo/path", branch: nil, isMain: false)
        #expect(wt.id == "/repo/path")
    }
}

// MARK: - ClaudeHookPayload Decoding Tests

struct ClaudeHookPayloadTests {

    @Test func decodeMinimalPayload() throws {
        let json = """
        {
            "hook_event_name": "Stop",
            "cwd": "/tmp"
        }
        """
        let payload = try JSONDecoder().decode(ClaudeHookPayload.self, from: Data(json.utf8))
        #expect(payload.hookEventName == .stop)
        #expect(payload.cwd == "/tmp")
        #expect(payload.toolName == nil)
        #expect(payload.sessionId == nil)
        #expect(payload.toolInput == nil)
    }

    @Test func decodeFullPayload() throws {
        let json = """
        {
            "hook_event_name": "PreToolUse",
            "cwd": "/repo",
            "tool_name": "Bash",
            "session_id": "sess-123",
            "message": "running command",
            "tool_input": {"command": "ls -la"}
        }
        """
        let payload = try JSONDecoder().decode(ClaudeHookPayload.self, from: Data(json.utf8))
        #expect(payload.hookEventName == .preToolUse)
        #expect(payload.toolName == "Bash")
        #expect(payload.sessionId == "sess-123")
        #expect(payload.message == "running command")
        #expect(payload.toolInput != nil)
        #expect(payload.toolInput!.contains("command"))
    }

    @Test func decodeWithNestedToolInput() throws {
        let json = """
        {
            "hook_event_name": "PreToolUse",
            "cwd": "/repo",
            "tool_input": {"key": "value", "nested": {"a": 1}}
        }
        """
        let payload = try JSONDecoder().decode(ClaudeHookPayload.self, from: Data(json.utf8))
        #expect(payload.toolInput != nil)
    }

    @Test func decodeNotification() throws {
        let json = """
        {
            "hook_event_name": "Notification",
            "cwd": "/repo",
            "notification_type": "info",
            "message": "Build complete",
            "is_muted": false
        }
        """
        let payload = try JSONDecoder().decode(ClaudeHookPayload.self, from: Data(json.utf8))
        #expect(payload.hookEventName == .notification)
        #expect(payload.notificationType == "info")
        #expect(payload.message == "Build complete")
        #expect(payload.isMuted == false)
    }

    @Test func decodeInvalidEventNameThrows() {
        let json = """
        {
            "hook_event_name": "InvalidEvent",
            "cwd": "/repo"
        }
        """
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ClaudeHookPayload.self, from: Data(json.utf8))
        }
    }
}

// MARK: - SessionAnnotation Tests

struct SessionAnnotationTests {

    @Test func outcomeDisplayLabels() {
        #expect(SessionOutcome.success.displayLabel == "Success")
        #expect(SessionOutcome.failure.displayLabel == "Failure")
        #expect(SessionOutcome.partial.displayLabel == "Partial")
    }

    @Test func failureReasonDisplayLabels() {
        #expect(FailureReason.instructionGap.displayLabel == "Instruction Gap")
        #expect(FailureReason.toolSelectionError.displayLabel == "Tool Selection")
        #expect(FailureReason.permissionDenied.displayLabel == "Permission Denied")
        #expect(FailureReason.hallucination.displayLabel == "Hallucination")
        #expect(FailureReason.other.displayLabel == "Other")
    }
}

// MARK: - GitError Tests

struct GitErrorTests {

    @Test func errorDescriptions() {
        #expect(GitError.commandFailed("oops").errorDescription == "oops")
        #expect(GitError.worktreeDirty("/repo").errorDescription == "Worktree has uncommitted changes.")
        #expect(GitError.timeout.errorDescription == "Git command timed out.")
    }
}

// MARK: - PermissionDefaultMode Tests

struct PermissionDefaultModeTests {

    @Test func displayNames() {
        #expect(PermissionDefaultMode.default.displayName == "Default")
        #expect(PermissionDefaultMode.acceptEdits.displayName == "Accept Edits")
        #expect(PermissionDefaultMode.plan.displayName == "Plan")
        #expect(PermissionDefaultMode.auto.displayName == "Auto")
        #expect(PermissionDefaultMode.bypassPermissions.displayName == "Bypass")
    }
}
