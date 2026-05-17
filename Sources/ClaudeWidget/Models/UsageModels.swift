import Foundation

// Kept minimal — data now comes from local Claude Code JSONL files, not the API.
enum APIError: LocalizedError {
    case http(Int, String)
    var errorDescription: String? {
        if case .http(let code, let body) = self { return "HTTP \(code): \(body)" }
        return nil
    }
}
