import Foundation
import MorseKit

/// Loads a plain-text file chosen in the Files picker.
enum TextImport {
    /// Files above this are refused outright.
    static let maxFileSize = 10 * 1024 * 1024
    /// Longer text is cut so the editor stays responsive; playback is capped earlier anyway
    /// (`PreparedText.defaultSymbolLimit`).
    static let maxCharacters = 150_000

    struct Result: Equatable {
        let text: String
        /// The file had more text than `maxCharacters`.
        let wasShortened: Bool
    }

    enum ImportError: LocalizedError, Equatable {
        case tooLarge(bytes: Int)
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case .tooLarge(let bytes):
                let size = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
                let limit = ByteCountFormatter.string(fromByteCount: Int64(TextImport.maxFileSize), countStyle: .file)
                return String(localized: "The file is too large (\(size)). The limit is \(limit).")
            case .unreadable(let reason):
                return String(localized: "The file could not be read: \(reason)")
            }
        }
    }

    static func load(from url: URL) throws -> Result {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
        }
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maxFileSize {
            throw ImportError.tooLarge(bytes: size)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.unreadable(error.localizedDescription)
        }
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> Result {
        guard data.count <= maxFileSize else {
            throw ImportError.tooLarge(bytes: data.count)
        }
        let text = TextDecoding.string(from: data)
        guard text.count > maxCharacters else {
            return Result(text: text, wasShortened: false)
        }
        return Result(text: String(text.prefix(maxCharacters)), wasShortened: true)
    }
}
