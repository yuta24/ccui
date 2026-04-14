import Foundation

@Observable
@MainActor
final class SessionEvaluationStore {
    private(set) var evaluation: SessionEvaluation?
    private(set) var sessionTitle: String?
    private(set) var isTruncated: Bool = false

    func open(session: AgentSession, title: String?) {
        evaluation = SessionEvaluation.compute(from: session)
        sessionTitle = title ?? String(session.id.prefix(8))
        isTruncated = session.isTruncated
    }

    func close() {
        evaluation = nil
        sessionTitle = nil
        isTruncated = false
    }
}
