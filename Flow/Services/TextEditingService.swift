import Foundation

enum TextEditingService {
    struct EditResult {
        let text: String
        let selection: NSRange
    }

    static func toggleLineComment(text: String, selection: NSRange, language: String?) -> EditResult? {
        guard let token = lineCommentToken(for: language) else { return nil }
        let nsText = text as NSString
        let targetRange = expandedLineRange(selection, in: nsText)
        let selectedText = nsText.substring(with: targetRange)
        let lines = selectedText.components(separatedBy: "\n")
        let hasTrailingNewline = selectedText.hasSuffix("\n")
        let editableLines = hasTrailingNewline ? Array(lines.dropLast()) : lines

        let shouldUncomment = editableLines
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix(token) }

        var delta = 0
        let transformed = editableLines.map { line -> String in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
            let indentation = line.prefix { $0 == " " || $0 == "\t" }
            let rest = line.dropFirst(indentation.count)

            if shouldUncomment {
                var mutable = String(rest)
                if mutable.hasPrefix(token + " ") {
                    mutable.removeFirst(token.count + 1)
                    delta -= token.count + 1
                } else if mutable.hasPrefix(token) {
                    mutable.removeFirst(token.count)
                    delta -= token.count
                }
                return indentation + mutable
            }

            delta += token.count + 1
            return indentation + token + " " + rest
        }

        var replacement = transformed.joined(separator: "\n")
        if hasTrailingNewline {
            replacement += "\n"
        }

        let newText = nsText.replacingCharacters(in: targetRange, with: replacement)
        return EditResult(
            text: newText,
            selection: NSRange(location: targetRange.location, length: max(0, targetRange.length + delta))
        )
    }

    static func duplicateLineOrSelection(text: String, selection: NSRange) -> EditResult {
        let nsText = text as NSString
        let targetRange = selection.length > 0 ? selection : expandedLineRange(selection, in: nsText)
        let selectedText = nsText.substring(with: targetRange)
        let insertion = selectedText.hasSuffix("\n") ? selectedText : selectedText + "\n"
        let insertLocation = NSMaxRange(targetRange)
        let newText = nsText.replacingCharacters(in: NSRange(location: insertLocation, length: 0), with: insertion)
        return EditResult(text: newText, selection: NSRange(location: insertLocation, length: selectedText.count))
    }

    static func trimTrailingWhitespace(text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { trimTrailingWhitespace($0) }
            .joined(separator: "\n")
    }

    private static func expandedLineRange(_ selection: NSRange, in text: NSString) -> NSRange {
        guard text.length > 0 else { return NSRange(location: 0, length: 0) }
        let safeLocation = min(selection.location, text.length)
        let safeLength = min(selection.length, max(0, text.length - safeLocation))
        return text.lineRange(for: NSRange(location: safeLocation, length: safeLength))
    }

    private static func trimTrailingWhitespace(_ line: String) -> String {
        var end = line.endIndex
        while end > line.startIndex {
            let previous = line.index(before: end)
            guard line[previous] == " " || line[previous] == "\t" else { break }
            end = previous
        }
        return String(line[..<end])
    }

    private static func lineCommentToken(for language: String?) -> String? {
        switch language {
        case "swift", "c", "cpp", "objectivec", "csharp", "java", "kotlin", "scala", "javascript", "typescript", "rust", "go", "dart", "zig", "php":
            return "//"
        case "python", "ruby", "bash", "zsh", "powershell", "makefile", "dockerfile", "yaml", "toml", "ini", "properties", "perl", "r":
            return "#"
        case "sql", "lua":
            return "--"
        case "html", "xml", "markdown", "plaintext", nil:
            return nil
        default:
            return "//"
        }
    }
}
