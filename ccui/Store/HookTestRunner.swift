import Foundation
import os
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

        // パイプからの読み取りをプロセス実行中に並行して行う。
        // waitUntilExit() 後に readDataToEndOfFile() を呼ぶと、
        // 出力がパイプバッファを超えた場合にデッドロックする。
        let outData = OSAllocatedUnfairLock<Data>(initialState: Data())
        let errData = OSAllocatedUnfairLock<Data>(initialState: Data())
        let readGroup = DispatchGroup()
        let readQueue = DispatchQueue(label: "HookTestRunner.pipeRead", attributes: .concurrent)

        readGroup.enter()
        readQueue.async {
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            outData.withLock { $0 = data }
            readGroup.leave()
        }
        readGroup.enter()
        readQueue.async {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            errData.withLock { $0 = data }
            readGroup.leave()
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
            readGroup.wait()
            return ("[error] \(error.localizedDescription)", -1)
        }

        runningProcess = process

        let result: (output: String, exitCode: Int32) = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global().async {
                    stdinPipe.fileHandleForWriting.write(payload)
                    stdinPipe.fileHandleForWriting.closeFile()

                    let timeoutItem = DispatchWorkItem { [weak process] in
                        if process?.isRunning == true { process?.terminate() }
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeoutItem)

                    process.waitUntilExit()
                    timeoutItem.cancel()
                    readGroup.wait()

                    let out = String(data: outData.withLock({ $0 }), encoding: .utf8) ?? ""
                    let err = String(data: errData.withLock({ $0 }), encoding: .utf8) ?? ""

                    var output = ""
                    if !out.isEmpty { output += out }
                    if !err.isEmpty { output += "[stderr] \(err)" }
                    if output.isEmpty { output = "(no output)" }

                    continuation.resume(returning: (output, process.terminationStatus))
                }
            }
        } onCancel: {
            process.terminate()
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
        case .sessionStart:
            payload["source"] = "startup"
            payload["model"] = "claude-sonnet-4-6"
        case .messageDisplay:
            payload["delta"] = "Sample assistant message"
        case .stop, .subagentStop:
            break
        }

        return (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
    }
}
