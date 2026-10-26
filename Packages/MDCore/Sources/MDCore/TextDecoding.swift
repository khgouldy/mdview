import Foundation

public enum TextDecoding {
    /// Decodes file bytes as UTF-8, then UTF-16 when a BOM is present, then Windows-1252.
    public static func decode(_ data: Data) -> String {
        if let text = String(bytes: data, encoding: .utf8) {
            return text
        }
        if hasUTF16ByteOrderMark(data), let text = String(bytes: data, encoding: .utf16) {
            return strippingByteOrderMark(text)
        }
        return decodeWindows1252(data)
    }

    private static func decodeWindows1252(_ data: Data) -> String {
        var text = ""
        text.reserveCapacity(data.count)
        for byte in data {
            text.unicodeScalars.append(windows1252[Int(byte)])
        }
        return text
    }

    private static func hasUTF16ByteOrderMark(_ data: Data) -> Bool {
        let prefix = data.prefix(2)
        guard prefix.count == 2 else {
            return false
        }
        let bytes = Array(prefix)
        let littleEndian = bytes[0] == 0xFF && bytes[1] == 0xFE
        let bigEndian = bytes[0] == 0xFE && bytes[1] == 0xFF
        return littleEndian || bigEndian
    }

    /// Windows-1252. Bytes 0x80-0x9F that the encoding leaves undefined stay as that C1 scalar.
    private static let windows1252: [Unicode.Scalar] = {
        var values = (UInt8.min ... UInt8.max).map { Unicode.Scalar($0) }
        let extras: [(UInt8, UInt32)] = [
            (0x80, 0x20AC),
            (0x82, 0x201A),
            (0x83, 0x0192),
            (0x84, 0x201E),
            (0x85, 0x2026),
            (0x86, 0x2020),
            (0x87, 0x2021),
            (0x88, 0x02C6),
            (0x89, 0x2030),
            (0x8A, 0x0160),
            (0x8B, 0x2039),
            (0x8C, 0x0152),
            (0x8E, 0x017D),
            (0x91, 0x2018),
            (0x92, 0x2019),
            (0x93, 0x201C),
            (0x94, 0x201D),
            (0x95, 0x2022),
            (0x96, 0x2013),
            (0x97, 0x2014),
            (0x98, 0x02DC),
            (0x99, 0x2122),
            (0x9A, 0x0161),
            (0x9B, 0x203A),
            (0x9C, 0x0153),
            (0x9E, 0x017E),
            (0x9F, 0x0178),
        ]
        for (byte, code) in extras {
            if let scalar = Unicode.Scalar(code) {
                values[Int(byte)] = scalar
            }
        }
        return values
    }()

    private static func strippingByteOrderMark(_ text: String) -> String {
        guard text.first == "\u{FEFF}" else {
            return text
        }
        return String(text.dropFirst())
    }
}
