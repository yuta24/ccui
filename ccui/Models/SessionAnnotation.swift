import Foundation

nonisolated enum SessionOutcome: String, Codable, CaseIterable, Sendable {
    case success
    case failure
    case partial
}

nonisolated enum FailureReason: String, Codable, CaseIterable, Sendable {
    case instructionGap
    case toolSelectionError
    case permissionDenied
    case hallucination
    case other
}

extension SessionOutcome {
    var displayLabel: String {
        switch self {
        case .success: "Success"
        case .failure: "Failure"
        case .partial: "Partial"
        }
    }
}

extension FailureReason {
    var displayLabel: String {
        switch self {
        case .instructionGap: "Instruction Gap"
        case .toolSelectionError: "Tool Selection"
        case .permissionDenied: "Permission Denied"
        case .hallucination: "Hallucination"
        case .other: "Other"
        }
    }
}
