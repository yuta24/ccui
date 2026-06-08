import Foundation
import Testing
@testable import ccui

/// `SessionActivity`/`SessionAttention` の値としての性質（表示ラベル・分類）を検証する。
/// イベント列からの導出ロジック（鮮度判定込み）は `AgentSession.snapshot` 側
/// （`ModelTests.swift` の `AgentSessionTests`）でカバーする。
struct SessionStateTests {

    // MARK: - displayLabel

    @Test func displayLabels() {
        #expect(SessionActivity.idle.displayLabel == "Idle")
        #expect(SessionActivity.thinking.displayLabel == "Thinking")
        #expect(SessionActivity.runningTool("Read").displayLabel == "Read")
        #expect(SessionActivity.waitingForUser.displayLabel == "Waiting")
        #expect(SessionActivity.finished.displayLabel == "Done")
        #expect(SessionActivity.unresponsive.displayLabel == "Unresponsive")
    }

    // MARK: - isActive

    @Test func isActiveForActiveStates() {
        #expect(SessionActivity.thinking.isActive == true)
        #expect(SessionActivity.runningTool("X").isActive == true)
        #expect(SessionActivity.waitingForUser.isActive == true)
    }

    @Test func isActiveForInactiveStates() {
        #expect(SessionActivity.idle.isActive == false)
        #expect(SessionActivity.finished.isActive == false)
        #expect(SessionActivity.unresponsive.isActive == false)
    }

    // MARK: - isTerminal

    @Test func isTerminalForTerminalStates() {
        #expect(SessionActivity.idle.isTerminal == true)
        #expect(SessionActivity.finished.isTerminal == true)
        #expect(SessionActivity.unresponsive.isTerminal == true)
    }

    @Test func isTerminalForNonTerminalStates() {
        #expect(SessionActivity.thinking.isTerminal == false)
        #expect(SessionActivity.runningTool("X").isTerminal == false)
        #expect(SessionActivity.waitingForUser.isTerminal == false)
    }

    // MARK: - SessionAttention.Reason

    @Test func attentionReasonsAreEquatableByValue() {
        #expect(SessionAttention.Reason.notification(message: "a") == .notification(message: "a"))
        #expect(SessionAttention.Reason.notification(message: "a") != .notification(message: "b"))
        #expect(SessionAttention.Reason.permissionRequest(tool: "Bash") == .permissionRequest(tool: "Bash"))
        #expect(SessionAttention.Reason.notification(message: "a") != .permissionRequest(tool: "a"))
    }
}
