import Foundation

nonisolated struct ContentSearchMatch: Identifiable, Hashable, Sendable {
    let id: String
    let lineNumber: Int
    let lineContent: String

    init(filePath: String, lineNumber: Int, lineContent: String) {
        self.id = "\(filePath):\(lineNumber)"
        self.lineNumber = lineNumber
        self.lineContent = lineContent
    }
}

nonisolated struct ContentSearchResult: Identifiable, Hashable, Sendable {
    let id: String
    let filePath: String
    let fileName: String
    let relativePath: String
    let matches: [ContentSearchMatch]

    init(filePath: String, fileName: String, relativePath: String, matches: [ContentSearchMatch]) {
        self.id = filePath
        self.filePath = filePath
        self.fileName = fileName
        self.relativePath = relativePath
        self.matches = matches
    }
}
