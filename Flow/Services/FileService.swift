import Foundation

struct LoadedFile {
    let url: URL
    let text: String
    let encoding: String.Encoding
    let lineEnding: LineEnding
    let byteCount: Int
}

enum FileService {
    enum FileError: LocalizedError {
        case unableToDecode(URL)
        case unableToEncode(String.Encoding)
        case binaryFile(URL)
        case fileTooLarge(URL, Int)

        var errorDescription: String? {
            switch self {
            case .unableToDecode(let url):
                "Flow could not decode \(url.lastPathComponent)."
            case .unableToEncode:
                "Flow could not encode this file with its current encoding."
            case .binaryFile(let url):
                "\(url.lastPathComponent) looks like a binary file, so Flow did not open it as text."
            case .fileTooLarge(let url, let byteCount):
                "\(url.lastPathComponent) is too large to open safely (\(ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)))."
            }
        }
    }

    private static let maxOpenableBytes = 50 * 1024 * 1024
    private static let binarySampleBytes = 16 * 1024

    static func load(url: URL) throws -> LoadedFile {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        let byteCount = values.fileSize ?? 0
        if byteCount > maxOpenableBytes {
            throw FileError.fileTooLarge(url, byteCount)
        }

        try rejectBinaryFileIfNeeded(url: url)

        let data = try Data(contentsOf: url)
        let decoded = try decode(data: data, url: url)
        let lineEnding = LineEnding.detect(in: decoded.text)
        let normalized = decoded.text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return LoadedFile(
            url: url,
            text: normalized,
            encoding: decoded.encoding,
            lineEnding: lineEnding,
            byteCount: data.count
        )
    }

    static func save(text: String, to url: URL, encoding: String.Encoding, lineEnding: LineEnding) throws {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let fileText = text.lineEndingNormalized(to: lineEnding.sequence)
        guard let data = fileText.data(using: encoding, allowLossyConversion: false) else {
            throw FileError.unableToEncode(encoding)
        }
        try data.write(to: url, options: .atomic)
    }

    private static func decode(data: Data, url: URL) throws -> (text: String, encoding: String.Encoding) {
        let preferred = encodingFromBOM(data) ?? .utf8
        if let string = String(data: data, encoding: preferred) {
            return (string, preferred)
        }

        for encoding in candidateEncodings where encoding != preferred {
            if let string = String(data: data, encoding: encoding) {
                return (string, encoding)
            }
        }

        throw FileError.unableToDecode(url)
    }

    private static func rejectBinaryFileIfNeeded(url: URL) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        let sample = try handle.read(upToCount: binarySampleBytes) ?? Data()
        guard !sample.isEmpty else { return }
        if sample.contains(0) {
            throw FileError.binaryFile(url)
        }

        let bytes = [UInt8](sample)
        let suspicious = bytes.filter { byte in
            if byte == 9 || byte == 10 || byte == 12 || byte == 13 { return false }
            if byte >= 32 { return false }
            return true
        }

        if Double(suspicious.count) / Double(bytes.count) > 0.08 {
            throw FileError.binaryFile(url)
        }
    }

    private static func encodingFromBOM(_ data: Data) -> String.Encoding? {
        guard data.count >= 2 else { return nil }
        let bytes = [UInt8](data.prefix(4))

        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { return .utf8 }
        if bytes.starts(with: [0xFF, 0xFE, 0x00, 0x00]) { return .utf32LittleEndian }
        if bytes.starts(with: [0x00, 0x00, 0xFE, 0xFF]) { return .utf32BigEndian }
        if bytes.starts(with: [0xFF, 0xFE]) { return .utf16LittleEndian }
        if bytes.starts(with: [0xFE, 0xFF]) { return .utf16BigEndian }
        return nil
    }

    private static let candidateEncodings: [String.Encoding] = [
        .utf8,
        .utf16,
        .utf16LittleEndian,
        .utf16BigEndian,
        .utf32,
        .utf32LittleEndian,
        .utf32BigEndian,
        .isoLatin1,
        .windowsCP1252,
        .macOSRoman
    ]
}
