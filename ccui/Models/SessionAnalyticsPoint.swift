import Foundation

nonisolated struct SessionAnalyticsPoint: Identifiable, Hashable, Sendable {
    let id: String
    let sessionStart: Date
    let autonomyScore: Double
    let interventionCount: Int
    let duration: TimeInterval?
    let toolCounts: [String: Int]
}
