import Foundation

enum TextLocationService {
    struct LineColumn: Equatable {
        let line: Int
        let column: Int
    }

    static func lineStarts(in text: NSString) -> [Int] {
        guard text.length > 0 else { return [0] }

        var starts = [0]
        var cursor = 0
        while cursor < text.length {
            let remaining = NSRange(location: cursor, length: text.length - cursor)
            let newline = text.range(of: "\n", options: [], range: remaining)
            guard newline.location != NSNotFound else { break }
            cursor = newline.location + 1
            starts.append(cursor)
        }
        return starts
    }

    static func lineColumn(for location: Int, lineStarts: [Int]) -> LineColumn {
        guard !lineStarts.isEmpty else { return LineColumn(line: 1, column: 1) }

        let clampedLocation = max(0, location)
        var low = 0
        var high = lineStarts.count - 1

        while low <= high {
            let mid = (low + high) / 2
            if lineStarts[mid] <= clampedLocation {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        let lineIndex = max(0, high)
        return LineColumn(
            line: lineIndex + 1,
            column: clampedLocation - lineStarts[lineIndex] + 1
        )
    }

    static func rangeForLine(_ line: Int, column: Int, in text: String) -> NSRange? {
        let nsText = text as NSString
        let starts = lineStarts(in: nsText)
        guard line >= 1, line <= starts.count else { return nil }

        let lineStart = starts[line - 1]
        let nextLineStart = line < starts.count ? starts[line] : nsText.length
        let lineEnd = max(lineStart, nextLineStart - (line < starts.count ? 1 : 0))
        let location = min(lineEnd, lineStart + max(0, column - 1))
        return NSRange(location: location, length: 0)
    }

    static func parseLineColumn(_ input: String) -> LineColumn? {
        let separators = CharacterSet(charactersIn: ":, ")
        let parts = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        guard let lineText = parts.first, let line = Int(lineText), line > 0 else {
            return nil
        }

        let column = parts.dropFirst().first.flatMap(Int.init) ?? 1
        return LineColumn(line: line, column: max(1, column))
    }
}
