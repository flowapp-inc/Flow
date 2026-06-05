import AppKit

final class MinimapNSView: NSView {
    var text = "" {
        didSet { needsDisplay = true }
    }

    var theme: FlowTheme = .theme(with: "flowDark") {
        didSet { needsDisplay = true }
    }

    var language: String? {
        didSet { needsDisplay = true }
    }

    var visibleFraction: ClosedRange<CGFloat> = 0...0 {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        theme.minimap.setFill()
        bounds.fill()

        let lines = text.components(separatedBy: "\n")
        guard !lines.isEmpty else { return }

        let lineStride = max(1, Int(ceil(Double(lines.count) / 1800.0)))
        let rowHeight = max(1, bounds.height / CGFloat(lines.count))

        for index in stride(from: 0, to: lines.count, by: lineStride) {
            let line = lines[index]
            let y = CGFloat(index) / CGFloat(max(lines.count, 1)) * bounds.height
            let indent = CGFloat(line.prefix { $0 == " " || $0 == "\t" }.count)
            let width = min(bounds.width - 12, max(8, CGFloat(line.count) * 0.6))
            let x = min(bounds.width - 14, 6 + indent * 0.7)

            color(for: line).withAlpha(0.54).setFill()
            NSBezierPath(rect: NSRect(x: x, y: y, width: width, height: max(1, rowHeight * CGFloat(lineStride) * 0.55))).fill()
        }

        let startY = visibleFraction.lowerBound * bounds.height
        let endY = max(startY + 18, visibleFraction.upperBound * bounds.height)
        theme.selection.withAlpha(0.18).setFill()
        NSBezierPath(roundedRect: NSRect(x: 2, y: startY, width: bounds.width - 4, height: min(bounds.height - startY, endY - startY)), xRadius: 4, yRadius: 4).fill()
    }

    private func color(for line: String) -> NSColor {
        guard language != nil else { return theme.minimapText }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") || trimmed.hasPrefix("/*") {
            return theme.syntax.commentColor
        }
        if trimmed.contains("\"") || trimmed.contains("'") {
            return theme.syntax.stringColor
        }
        if trimmed.range(of: #"\b(class|struct|enum|func|let|var|import|return|if|else|for|while|switch|case)\b"#, options: .regularExpression) != nil {
            return theme.syntax.keywordColor
        }
        if trimmed.range(of: #"\b[0-9]+(\.[0-9]+)?\b"#, options: .regularExpression) != nil {
            return theme.syntax.numberColor
        }
        return theme.minimapText
    }
}
