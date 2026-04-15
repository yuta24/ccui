import Foundation
import OSLog

@Observable
@MainActor
final class HookTestRunner {
    enum RunState: Sendable {
        case idle
        case running
        case finished(output: String, exitCode: Int32)
    }

    private(set) var state: RunState = .idle
    /// Tracks which entry this run belongs to
    private(set) var runEntryID: UUID?
    private var runningProcess: Process?

    /// Run all commands in an entry sequentially, collecting combined output.
    func runAll(commands: [String], entryID: UUID, eventName: ClaudeHookPayload.HookEventName, worktreePath: String) async {
        state = .running
        runEntryID = entryID

        var combinedOutput = ""
        var lastExitCode: Int32 = 0

        for (index, command) in commands.enumerated() {
            let result = await execute(command: command, eventName: eventName, worktreePath: worktreePath)
            combinedOutput += "$ \(command)\n\(result.output)\n"
            lastExitCode = result.exitCode
            if result.exitCode != 0 {
                if index < commands.count - 1 {
                    combinedOutput += "(stopped: exit \(result.exitCode))\n"
                }
                break
            }
        }

        runningProcess = nil
        if case .running = state {
            state = .finished(output: combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines), exitCode: lastExitCode)
        }
    }

    private func execute(command: String, eventName: ClaudeHookPayload.HookEventName, worktreePath: String) async -> (output: String, exitCode: Int32) {
        let payload = Self.samplePayload(for: eventName, worktreePath: worktreePath)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]

        var env = ProcessInfo.processInfo.environment
        env["CCUI_SESSION"] = "dry-run-test"
        process.environment = env

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return ("[error] \(error.localizedDescription)", -1)
        }

        runningProcess = process

        let result: (output: String, exitCode: Int32) = await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                stdinPipe.fileHandleForWriting.write(payload)
                stdinPipe.fileHandleForWriting.closeFile()

                // Timeout after 10 seconds
                let timeoutItem = DispatchWorkItem { [weak process] in
                    if process?.isRunning == true { process?.terminate() }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeoutItem)

                process.waitUntilExit()
                timeoutItem.cancel()

                let out = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                var output = ""
                if !out.isEmpty { output += out }
                if !err.isEmpty { output += "[stderr] \(err)" }
                if output.isEmpty { output = "(no output)" }

                continuation.resume(returning: (output, process.terminationStatus))
            }
        }

        return result
    }

    func cancel() {
        runningProcess?.terminate()
        runningProcess = nil
        state = .idle
        runEntryID = nil
    }

    func resetState() {
        if case .running = state { return }
        state = .idle
        runEntryID = nil
    }

    /// Check if the current run result belongs to this entry
    func stateFor(entryID: UUID) -> RunState {
        guard runEntryID == entryID else { return .idle }
        return state
    }

    // MARK: - Sample Payload

    nonisolated static func samplePayload(for eventName: ClaudeHookPayload.HookEventName, worktreePath: String) -> Data {
        var payload: [String: Any] = [
            "hook_event_name": eventName.rawValue,
            "cwd": worktreePath,
            "session_id": "dry-run-test"
        ]

        switch eventName {
        case .preToolUse, .postToolUse:
            payload["tool_name"] = "Bash"
            payload["tool_input"] = ["command": "echo hello"]
        case .notification:
            payload["message"] = "Test notification"
            payload["notification_type"] = "info"
        case .permissionRequest:
            payload["tool_name"] = "Bash"
        case .userPromptSubmit:
            payload["prompt"] = "test prompt"
        case .stop, .subagentStop:
            break
        }

        return (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
    }
}
