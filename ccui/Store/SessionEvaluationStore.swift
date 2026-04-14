import Foundation

@Observable
@MainActor
final class SessionEvaluationStore {
    private(set) var evaluation: SessionEvaluation?
    private(set) var sessionTitle: String?

    func open(session: AgentSession, title: String?) {
        evaluation = SessionEvaluation.compute(from: session)
        sessionTitle = title ?? String(session.id.prefix(8))
    }

    func close() {
        evaluation = nil
        sessionTitle = nil
    }
}
