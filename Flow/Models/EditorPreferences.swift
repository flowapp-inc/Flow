import AppKit
import Foundation

final class EditorPreferences: ObservableObject {
    private enum Keys {
        static let themeID = "Flow.themeID"
        static let fontName = "Flow.fontName"
        static let fontSize = "Flow.fontSize"
        static let wordWrap = "Flow.wordWrap"
        static let showLineNumbers = "Flow.showLineNumbers"
        static let showMinimap = "Flow.showMinimap"
        static let titlebarFollowsTheme = "Flow.titlebarFollowsTheme"
        static let sidebarVisible = "Flow.sidebarVisible"
        static let splitRatio = "Flow.splitRatio"
        static let recentBookmarks = "Flow.recentBookmarks"
        static let openBookmarks = "Flow.openBookmarks"
    }

    private let defaults: UserDefaults

    @Published var themeID: String {
        didSet { defaults.set(themeID, forKey: Keys.themeID) }
    }

    @Published var fontName: String {
        didSet { defaults.set(fontName, forKey: Keys.fontName) }
    }

    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Keys.fontSize) }
    }

    @Published var wordWrap: Bool {
        didSet { defaults.set(wordWrap, forKey: Keys.wordWrap) }
    }

    @Published var showLineNumbers: Bool {
        didSet { defaults.set(showLineNumbers, forKey: Keys.showLineNumbers) }
    }

    @Published var showMinimap: Bool {
        didSet { defaults.set(showMinimap, forKey: Keys.showMinimap) }
    }

    @Published var titlebarFollowsTheme: Bool {
        didSet { defaults.set(titlebarFollowsTheme, forKey: Keys.titlebarFollowsTheme) }
    }

    @Published var sidebarVisible: Bool {
        didSet { defaults.set(sidebarVisible, forKey: Keys.sidebarVisible) }
    }

    @Published var splitRatio: Double {
        didSet {
            defaults.set(Self.clampedSplitRatio(splitRatio), forKey: Keys.splitRatio)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        themeID = defaults.string(forKey: Keys.themeID) ?? "flowDark"
        fontName = defaults.string(forKey: Keys.fontName) ?? "SF Mono"

        let savedFontSize = defaults.double(forKey: Keys.fontSize)
        fontSize = savedFontSize > 0 ? savedFontSize : 14

        if defaults.object(forKey: Keys.wordWrap) == nil {
            wordWrap = false
        } else {
            wordWrap = defaults.bool(forKey: Keys.wordWrap)
        }

        if defaults.object(forKey: Keys.showLineNumbers) == nil {
            showLineNumbers = true
        } else {
            showLineNumbers = defaults.bool(forKey: Keys.showLineNumbers)
        }

        if defaults.object(forKey: Keys.showMinimap) == nil {
            showMinimap = true
        } else {
            showMinimap = defaults.bool(forKey: Keys.showMinimap)
        }

        if defaults.object(forKey: Keys.titlebarFollowsTheme) == nil {
            titlebarFollowsTheme = true
        } else {
            titlebarFollowsTheme = defaults.bool(forKey: Keys.titlebarFollowsTheme)
        }

        if defaults.object(forKey: Keys.sidebarVisible) == nil {
            sidebarVisible = true
        } else {
            sidebarVisible = defaults.bool(forKey: Keys.sidebarVisible)
        }

        let savedSplitRatio = defaults.double(forKey: Keys.splitRatio)
        splitRatio = savedSplitRatio > 0 ? Self.clampedSplitRatio(savedSplitRatio) : 0.5
    }

    var theme: FlowTheme {
        FlowTheme.theme(with: themeID)
    }

    var editorFont: NSFont {
        NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    var openBookmarks: [Data] {
        get { defaults.array(forKey: Keys.openBookmarks) as? [Data] ?? [] }
        set { defaults.set(newValue, forKey: Keys.openBookmarks) }
    }

    var recentBookmarks: [Data] {
        get { defaults.array(forKey: Keys.recentBookmarks) as? [Data] ?? [] }
        set { defaults.set(newValue, forKey: Keys.recentBookmarks) }
    }

    func rememberOpenFiles(_ urls: [URL]) {
        openBookmarks = urls.compactMap { BookmarkStore.bookmarkData(for: $0) }
    }

    func rememberRecentFile(_ url: URL) {
        guard let data = BookmarkStore.bookmarkData(for: url) else { return }
        var all = recentBookmarks.filter { $0 != data }
        all.insert(data, at: 0)
        recentBookmarks = Array(all.prefix(20))
    }

    private static func clampedSplitRatio(_ value: Double) -> Double {
        min(0.82, max(0.18, value))
    }
}
