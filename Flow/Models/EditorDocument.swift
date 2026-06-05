import CoreGraphics
import Foundation

enum EditorDocumentKind: Equatable {
    case text
    case image
}

final class EditorDocument: ObservableObject, Identifiable {
    let id: UUID

    @Published var kind: EditorDocumentKind
    @Published var url: URL?
    @Published var text: String
    @Published var imageData: Data?
    @Published var imagePixelSize: CGSize?
    @Published var imageFormat: String?
    @Published var isDirty: Bool
    @Published var detectedLanguage: String? {
        didSet {
            languageRevision += 1
            updateResolvedSyntaxLanguage()
        }
    }
    @Published var languageOverride: String? {
        didSet {
            languageRevision += 1
            updateResolvedSyntaxLanguage()
        }
    }
    @Published var resolvedSyntaxLanguage: String
    @Published var languageRevision = 0
    @Published var encoding: String.Encoding
    @Published var lineEnding: LineEnding
    @Published var byteCount: Int
    @Published private(set) var lineCount = 1
    @Published var wordWrapOverride: Bool?
    @Published var findRanges: [NSRange] = [] {
        didSet { findRevision += 1 }
    }
    @Published var selectedFindRange: NSRange? {
        didSet { findRevision += 1 }
    }
    @Published var findRevision = 0
    @Published var selectionRequestID = UUID()
    @Published var selectionRange = NSRange(location: 0, length: 0)

    private var savedSnapshot: String

    init(
        id: UUID = UUID(),
        url: URL? = nil,
        text: String = "",
        encoding: String.Encoding = .utf8,
        lineEnding: LineEnding = .lf,
        byteCount: Int = 0,
        languageOverride: String? = nil,
        isDirty: Bool = false,
        kind: EditorDocumentKind = .text,
        imageData: Data? = nil,
        imagePixelSize: CGSize? = nil,
        imageFormat: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.url = url
        self.text = text
        self.imageData = imageData
        self.imagePixelSize = imagePixelSize
        self.imageFormat = imageFormat
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.byteCount = byteCount
        self.lineCount = kind == .text ? Self.countLines(in: text) : 0
        self.languageOverride = languageOverride
        self.isDirty = isDirty
        savedSnapshot = text
        let language = kind == .image ? "image" : LanguageDetector.detectLanguage(for: url, contents: text) ?? "plaintext"
        detectedLanguage = language
        resolvedSyntaxLanguage = languageOverride ?? language
    }

    convenience init(image loaded: LoadedImageFile) {
        self.init(
            url: loaded.url,
            text: "",
            byteCount: loaded.byteCount,
            isDirty: false,
            kind: .image,
            imageData: loaded.data,
            imagePixelSize: loaded.pixelSize,
            imageFormat: loaded.format
        )
    }

    var title: String {
        url?.lastPathComponent ?? "Untitled"
    }

    var subtitle: String {
        guard let url else { return "Unsaved document" }
        return url.deletingLastPathComponent().path
    }

    var displayLanguage: String {
        if kind == .image {
            return imageFormat ?? "image"
        }
        return resolvedSyntaxLanguage
    }

    var effectiveLanguage: String? {
        guard kind == .text else { return nil }
        let language = resolvedSyntaxLanguage
        return language == "plaintext" ? nil : language
    }

    var resolvedLanguage: String {
        guard kind == .text else { return "image" }
        return languageOverride ?? detectedLanguage ?? "plaintext"
    }

    var textLength: Int {
        guard kind == .text else { return 0 }
        return (text as NSString).length
    }

    var largeFileModeEnabled: Bool {
        guard kind == .text else { return false }
        return textLength > 260_000 || byteCount > 1_000_000
    }

    var largeFileModeReason: String {
        if byteCount > 1_000_000 {
            return ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
        }
        return "\(textLength.formatted()) characters"
    }

    var maxFindHighlights: Int {
        largeFileModeEnabled ? 800 : 5_000
    }

    var shouldDisableLiveRegexSearch: Bool {
        largeFileModeEnabled
    }

    var shouldShowDetailedMinimap: Bool {
        guard kind == .text else { return false }
        return !largeFileModeEnabled && textLength < 500_000 && byteCount < 2_500_000
    }

    var shouldUseViewportHighlighting: Bool {
        guard kind == .text else { return false }
        return largeFileModeEnabled || textLength > 180_000 || byteCount > 512 * 1024
    }

    var shouldAvoidHighlightr: Bool {
        guard kind == .text else { return true }
        return textLength > 750_000 || byteCount > 1_500_000
    }

    func replaceText(_ newText: String, markDirty: Bool = true) {
        guard kind == .text else { return }
        text = newText
        lineCount = Self.countLines(in: newText)
        byteCount = newText.data(using: encoding)?.count ?? byteCount
        let language = LanguageDetector.detectLanguage(for: url, contents: newText)
        if detectedLanguage != language {
            detectedLanguage = language
        }
        updateResolvedSyntaxLanguage()
        if markDirty {
            isDirty = newText != savedSnapshot
        }
    }

    func markSaved(url: URL, text savedText: String, encoding: String.Encoding, lineEnding: LineEnding) {
        guard kind == .text else { return }
        self.url = url
        self.text = savedText
        self.encoding = encoding
        self.lineEnding = lineEnding
        byteCount = savedText.data(using: encoding)?.count ?? byteCount
        lineCount = Self.countLines(in: savedText)
        savedSnapshot = savedText
        let language = LanguageDetector.detectLanguage(for: url, contents: savedText)
        if detectedLanguage != language {
            detectedLanguage = language
        }
        updateResolvedSyntaxLanguage()
        isDirty = false
    }

    func updateResolvedSyntaxLanguage() {
        guard kind == .text else {
            if resolvedSyntaxLanguage != "image" {
                resolvedSyntaxLanguage = "image"
                languageRevision += 1
            }
            return
        }
        let language = languageOverride ?? LanguageDetector.detectLanguage(for: url, contents: text) ?? detectedLanguage ?? "plaintext"
        if resolvedSyntaxLanguage != language {
            resolvedSyntaxLanguage = language
            languageRevision += 1
        }
    }

    func requestSelection(_ range: NSRange) {
        selectionRange = range
        selectionRequestID = UUID()
    }

    private static func countLines(in text: String) -> Int {
        guard !text.isEmpty else { return 1 }
        var count = 1
        for scalar in text.unicodeScalars where scalar.value == 10 {
            count += 1
        }
        return count
    }
}
