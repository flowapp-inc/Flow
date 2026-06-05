import AppKit

final class CodeTextView: NSTextView {
    var flowTheme: FlowTheme = .theme(with: "flowDark") {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func drawBackground(in rect: NSRect) {
        flowTheme.background.setFill()
        rect.fill()
        drawCurrentLineHighlight()
        drawMatchingBracketHighlights()
    }

    private func drawCurrentLineHighlight() {
        guard let layoutManager, let textContainer else { return }

        let location = min(selectedRange().location, max((string as NSString).length - 1, 0))
        let lineRange = (string as NSString).lineRange(for: NSRange(location: location, length: 0))
        let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
            .insetBy(dx: -textContainerInset.width, dy: 0)

        flowTheme.lineHighlight.setFill()
        let fallbackHeight = font.map { ceil($0.ascender - $0.descender + $0.leading) } ?? 18
        NSBezierPath(rect: NSRect(x: 0, y: rect.minY, width: bounds.width, height: max(rect.height, fallbackHeight))).fill()
    }

    private func drawMatchingBracketHighlights() {
        guard let layoutManager, let textContainer else { return }
        for range in bracketRangesNearCaret() {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            rect = rect.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y).insetBy(dx: -2, dy: -1)
            flowTheme.accent.withAlpha(0.28).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3).fill()
        }
    }

    private func bracketRangesNearCaret() -> [NSRange] {
        let nsString = string as NSString
        guard nsString.length > 0 else { return [] }

        let caret = selectedRange().location
        let candidates = [caret - 1, caret].filter { $0 >= 0 && $0 < nsString.length }
        let pairs: [Character: Character] = ["(": ")", "[": "]", "{": "}"]
        let reversePairs = Dictionary(uniqueKeysWithValues: pairs.map { ($0.value, $0.key) })

        for index in candidates {
            let character = Character(nsString.substring(with: NSRange(location: index, length: 1)))
            if let closing = pairs[character],
               let match = findMatchingBracket(from: index, open: character, close: closing, forward: true) {
                return [NSRange(location: index, length: 1), NSRange(location: match, length: 1)]
            }
            if let opening = reversePairs[character],
               let match = findMatchingBracket(from: index, open: opening, close: character, forward: false) {
                return [NSRange(location: index, length: 1), NSRange(location: match, length: 1)]
            }
        }

        return []
    }

    private func findMatchingBracket(from index: Int, open: Character, close: Character, forward: Bool) -> Int? {
        let characters = Array(string)
        guard !characters.isEmpty else { return nil }

        var depth = 0
        var cursor = index

        while cursor >= 0 && cursor < characters.count {
            let character = characters[cursor]
            if character == open {
                depth += forward ? 1 : -1
            } else if character == close {
                depth += forward ? -1 : 1
            }

            if depth == 0 && cursor != index {
                return cursor
            }

            cursor += forward ? 1 : -1
        }

        return nil
    }
}
