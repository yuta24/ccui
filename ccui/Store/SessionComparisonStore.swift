import Foundation

@Observable
@MainActor
final class SessionComparisonStore {
    private(set) var isVisible = false
    private(set) var sessionA: AgentSession?
    private(set) var sessionB: AgentSession?
    private(set) var evaluationA: SessionEvaluation?
    private(set) var evaluationB: SessionEvaluation?
    private(set) var titleA: String?
    private(set) var titleB: String?

    func open(sessionA: AgentSession, titleA: String?, sessionB: AgentSession, titleB: String?) {
        self.sessionA = sessionA
        self.sessionB = sessionB
        self.evaluationA = SessionEvaluation.compute(from: sessionA)
        self.evaluationB = SessionEvaluation.compute(from: sessionB)
        self.titleA = titleA ?? String(sessionA.id.prefix(8))
        self.titleB = titleB ?? String(sessionB.id.prefix(8))
        isVisible = true
    }

    func close() {
        isVisible = false
        sessionA = nil
        sessionB = nil
        evaluationA = nil
        evaluationB = nil
        titleA = nil
        titleB = nil
    }
}
