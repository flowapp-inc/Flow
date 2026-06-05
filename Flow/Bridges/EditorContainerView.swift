import AppKit

final class EditorContainerView: NSView {
    let scrollView: NSScrollView
    let textView: CodeTextView
    let minimapView: MinimapNSView
    let lineNumberRuler: LineNumberRulerView

    var onVisibleRangeChanged: (() -> Void)?

    private var showMinimap = true
    private var showLineNumbers = true
    private let gutterWidth: CGFloat = 52
    private let minimapWidth: CGFloat = 68

    override init(frame frameRect: NSRect) {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))

        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        textView = CodeTextView(frame: .zero, textContainer: textContainer)
        scrollView = NSScrollView(frame: .zero)
        minimapView = MinimapNSView(frame: .zero)
        lineNumberRuler = LineNumberRulerView(textView: textView)

        super.init(frame: frameRect)

        wantsLayer = true
        configureTextView()
        configureScrollView()

        addSubview(lineNumberRuler)
        addSubview(scrollView)
        addSubview(minimapView)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(boundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layout() {
        super.layout()
        let gutterSpace = showLineNumbers ? gutterWidth : 0
        let minimapSpace = showMinimap ? minimapWidth : 0
        lineNumberRuler.frame = NSRect(x: 0, y: 0, width: gutterSpace, height: bounds.height)
        lineNumberRuler.isHidden = !showLineNumbers
        scrollView.frame = NSRect(x: gutterSpace, y: 0, width: max(0, bounds.width - gutterSpace - minimapSpace), height: bounds.height)
        minimapView.frame = NSRect(x: bounds.width - minimapSpace, y: 0, width: minimapSpace, height: bounds.height)
        minimapView.isHidden = !showMinimap
    }

    func apply(document: EditorDocument, preferences: EditorPreferences, theme: FlowTheme) {
        textView.flowTheme = theme
        textView.backgroundColor = theme.background
        textView.insertionPointColor = theme.cursor
        textView.selectedTextAttributes = [
            .backgroundColor: theme.selection,
            .foregroundColor: theme.text
        ]
        textView.typingAttributes = baseAttributes(font: preferences.editorFont, theme: theme)

        scrollView.backgroundColor = theme.background
        scrollView.drawsBackground = true
        showLineNumbers = preferences.showLineNumbers
        lineNumberRuler.theme = theme
        lineNumberRuler.needsDisplay = true

        showMinimap = preferences.showMinimap && document.shouldShowDetailedMinimap
        minimapView.theme = theme
        minimapView.language = document.effectiveLanguage
        minimapView.text = showMinimap ? document.text : ""
        updateWrapping(enabled: document.wordWrapOverride ?? preferences.wordWrap)
        updateVisibleFraction()
        needsLayout = true
    }

    func baseAttributes(font: NSFont, theme: FlowTheme) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.defaultTabInterval = CGFloat(FormatterService.preferredIndentWidth(for: nil)) * font.maximumAdvancement.width

        return [
            .font: font,
            .foregroundColor: theme.text,
            .backgroundColor: theme.background,
            .paragraphStyle: paragraph
        ]
    }

    @objc private func boundsDidChange() {
        lineNumberRuler.needsDisplay = true
        updateVisibleFraction()
        onVisibleRangeChanged?()
    }

    private func configureTextView() {
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 16, height: 18)
        textView.allowsUndo = true
        textView.isRichText = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.importsGraphics = false
        textView.usesFindBar = false
        textView.allowsDocumentBackgroundColorChange = false
    }

    private func configureScrollView() {
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.contentView.postsBoundsChangedNotifications = true
    }

    private func updateWrapping(enabled: Bool) {
        if enabled {
            scrollView.hasHorizontalScroller = false
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        } else {
            scrollView.hasHorizontalScroller = true
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.height]
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    private func updateVisibleFraction() {
        let documentHeight = max(textView.bounds.height, 1)
        let visible = scrollView.contentView.bounds
        let lower = max(0, min(1, visible.minY / documentHeight))
        let upper = max(lower, min(1, visible.maxY / documentHeight))
        minimapView.visibleFraction = lower...upper
    }
}
