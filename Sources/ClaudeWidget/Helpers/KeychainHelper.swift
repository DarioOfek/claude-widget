import Foundation

// File-based key storage (~/.config/claude_widget/apikey)
// Avoids macOS Keychain permission dialogs for unsigned apps.
enum KeychainHelper {
    private static var keyFile: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/claude_widget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("apikey")
    }

    static func save(_ key: String) {
        try? key.write(to: keyFile, atomically: true, encoding: .utf8)
        // Restrict permissions to owner-read-only
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: keyFile.path)
    }

    static func load() -> String? {
        guard let key = try? String(contentsOf: keyFile, encoding: .utf8) else { return nil }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func delete() {
        try? FileManager.default.removeItem(at: keyFile)
    }
}
