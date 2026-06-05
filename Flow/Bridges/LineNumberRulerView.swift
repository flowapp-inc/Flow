import AppKit

final class LineNumberRulerView: NSView {
    weak var textView: NSTextView?
    var theme: FlowTheme = .theme(with: "flowDark") {
        didSet { needsDisplay = true }
    }

    init(textView: NSTextView) {
        self.textView = textView
        super.init(frame: NSRect(x: 0, y: 0, width: 52, height: 0))
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView = textView.enclosingScrollView else {
            return
        }

        theme.background.setFill()
        bounds.fill()

        let visibleRect = scrollView.contentView.bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let nsString = textView.string as NSString

        if nsString.length == 0 {
            draw(lineNumber: 1, y: 18)
            return
        }

        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var effectiveRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
            let charRange = layoutManager.characterRange(forGlyphRange: effectiveRange, actualGlyphRange: nil)
            let logicalLineRange = nsString.lineRange(for: NSRange(location: min(charRange.location, max(nsString.length - 1, 0)), length: 0))
            let y = lineRect.minY + textView.textContainerOrigin.y - visibleRect.minY + 1
            if charRange.location == logicalLineRange.location {
                let number = lineNumber(at: charRange.location, in: nsString)
                draw(lineNumber: number, y: y)
            } else {
                drawContinuationMarker(y: y)
            }
            glyphIndex = max(NSMaxRange(effectiveRange), glyphIndex + 1)
        }

        drawExtraLineNumberIfNeeded(
            textView: textView,
            layoutManager: layoutManager,
            visibleRect: visibleRect,
            string: nsString
        )
    }

    private func draw(lineNumber: Int, y: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: theme.gutterText,
            .paragraphStyle: paragraph
        ]

        let string = "\(lineNumber)" as NSString
        string.draw(
            in: NSRect(x: 0, y: y, width: bounds.width - 10, height: 16),
            withAttributes: attributes
        )
    }

    private func drawContinuationMarker(y: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: theme.gutterText.withAlpha(0.38),
            .paragraphStyle: paragraph
        ]

        (">" as NSString).draw(
            in: NSRect(x: 0, y: y, width: bounds.width - 12, height: 16),
            withAttributes: attributes
        )
    }

    private func drawExtraLineNumberIfNeeded(
        textView: NSTextView,
        layoutManager: NSLayoutManager,
        visibleRect: NSRect,
        string: NSString
    ) {
        guard string.length == 0 || string.substring(from: max(0, string.length - 1)) == "\n" else { return }

        let rect = layoutManager.extraLineFragmentRect
        guard rect != .zero else { return }

        let y = rect.minY + textView.textContainerOrigin.y - visibleRect.minY + 1
        guard y >= -18, y <= bounds.height + 18 else { return }
        draw(lineNumber: lineNumber(at: string.length, in: string), y: y)
    }

    private func lineNumber(at location: Int, in string: NSString) -> Int {
        guard location > 0 else { return 1 }
        var line = 1
        var index = 0
        while index < min(location, string.length) {
            if string.character(at: index) == 10 {
                line += 1
            }
            index += 1
        }
        return line
    }
}
