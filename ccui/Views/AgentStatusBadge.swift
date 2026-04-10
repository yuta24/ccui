import SwiftUI

struct AgentStatusBadge: View {
    let state: AgentState

    var body: some View {
        if state != .idle {
            Image(systemName: state.systemImageName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(state.color)
        }
    }
}
