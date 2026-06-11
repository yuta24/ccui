import Foundation

/// JSON ファイルベースの永続化で共通する読み込みユーティリティ。
enum PersistenceFile {
    /// ファイルを読み込む。ファイルが存在しない場合、または 0 byte
    /// （直前の atomic 書き込み失敗・ファイル同期ツール等による不完全な状態）の
    /// 場合は nil を返し、初回起動相当として扱えるようにする。
    /// ファイルが存在し非空だが読み込みに失敗した場合は throw する。
    static func readDataIfPresent(at url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return data.isEmpty ? nil : data
    }
}
