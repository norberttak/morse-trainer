import Foundation

/// Turns the bytes of a plain-text file into a string, guessing the encoding.
///
/// Order: byte-order mark (UTF-8, UTF-16 LE/BE) → valid UTF-8 → Windows-1252, which also
/// covers Latin-1 and never fails, so any file produces some text.
public enum TextDecoding {
    public static func string(from data: Data) -> String {
        let bytes = [UInt8](data.prefix(3))
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(decoding: data.dropFirst(3), as: UTF8.self)
        }
        if bytes.starts(with: [0xFF, 0xFE]), let text = String(data: data, encoding: .utf16LittleEndian) {
            return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        }
        if bytes.starts(with: [0xFE, 0xFF]), let text = String(data: data, encoding: .utf16BigEndian) {
            return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .windowsCP1252) {
            return text
        }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }
}
