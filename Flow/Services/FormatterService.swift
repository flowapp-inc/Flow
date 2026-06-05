import Foundation

enum FormatterService {
    static func format(_ text: String, language: String?) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        if language == "json", let pretty = prettyPrintedJSON(normalized) {
            return pretty
        }

        if shouldCleanOnly(language: language) {
            return cleanWhitespace(normalized)
        }

        let indentWidth = preferredIndentWidth(for: language)
        var indentLevel = 0
        var output: [String] = []
        var previousBlank = false

        for rawLine in normalized.components(separatedBy: "\n") {
            let trimmedRight = rawLine.trimmingCharacters(in: .whitespaces)
            let trimmed = trimmedRight.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                if !previousBlank {
                    output.append("")
                }
                previousBlank = true
                continue
            }
            previousBlank = false

            if shouldDedentBeforeLine(trimmed, language: language) {
                indentLevel = max(0, indentLevel - 1)
            }

            output.append(String(repeating: " ", count: indentLevel * indentWidth) + trimmed)

            indentLevel = max(0, indentLevel + indentationDelta(for: trimmed, language: language))
        }

        return output.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    static func indentationAfterNewline(in text: String, location: Int, language: String?) -> String {
        let nsText = text as NSString
        let safeLocation = min(max(location, 0), nsText.length)
        let previousRange = nsText.lineRange(for: NSRange(location: max(safeLocation - 1, 0), length: 0))
        let previousLine = nsText.substring(with: previousRange)
        let currentIndent = previousLine.prefix { $0 == " " || $0 == "\t" }
        let trimmed = previousLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let width = preferredIndentWidth(for: language)

        if shouldIndentAfterLine(trimmed, language: language) {
            return "\n" + currentIndent + String(repeating: " ", count: width)
        }
        return "\n" + currentIndent
    }

    static func preferredIndentWidth(for language: String?) -> Int {
        switch language {
        case "javascript", "typescript", "json", "html", "xml", "css", "scss", "yaml", "ruby", "php", "kotlin", "scala", "groovy", "dart":
            return 2
        case "makefile":
            return 1
        default:
            return 4
        }
    }

    private static func shouldCleanOnly(language: String?) -> Bool {
        switch language {
        case "markdown", "plaintext", "makefile", "ini", "properties", "toml", "diff", "latex", "asciidoc":
            return true
        default:
            return false
        }
    }

    private static func cleanWhitespace(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n").map { line in
            trimTrailingWhitespace(line)
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
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

    private static func prettyPrintedJSON(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: pretty, encoding: .utf8) else {
            return nil
        }
        return string + "\n"
    }

    private static func shouldDedentBeforeLine(_ line: String, language: String?) -> Bool {
        if line.hasPrefix("}") || line.hasPrefix("]") || line.hasPrefix(")") {
            return true
        }
        if language == "html" || language == "xml" {
            return line.hasPrefix("</")
        }
        if ["case ", "default:"].contains(where: { line.hasPrefix($0) }) {
            return true
        }
        return false
    }

    private static func shouldIndentAfterLine(_ line: String, language: String?) -> Bool {
        guard !line.isEmpty else { return false }
        if language == "python" || language == "yaml" || language == "ruby" || language == "elixir" {
            return line.hasSuffix(":") || line.hasSuffix("do")
        }
        if language == "html" || language == "xml" {
            return isOpeningTag(line)
        }
        return ["{", "[", "("].contains { line.hasSuffix($0) }
    }

    private static func indentationDelta(for line: String, language: String?) -> Int {
        var delta = bracketDelta(for: line)

        if language == "python" || language == "yaml" || language == "ruby" || language == "elixir" {
            if line.hasSuffix(":") || line.hasSuffix("do") {
                delta += 1
            }
            if ["return", "pass", "break", "continue", "raise"].contains(where: { line == $0 || line.hasPrefix($0 + " ") }) {
                delta -= 1
            }
        }

        if language == "html" || language == "xml", isOpeningTag(line) {
            delta += 1
        }

        if ["case ", "default:"].contains(where: { line.hasPrefix($0) }) {
            delta += 1
        }

        return delta
    }

    private static func bracketDelta(for line: String) -> Int {
        var delta = 0
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaped = false

        for character in line {
            if escaped {
                escaped = false
                continue
            }

            if character == "\\" {
                escaped = true
                continue
            }

            if character == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                continue
            }

            if character == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                continue
            }

            guard !inSingleQuote && !inDoubleQuote else { continue }

            switch character {
            case "{", "[", "(":
                delta += 1
            case "}", "]", ")":
                delta -= 1
            default:
                break
            }
        }

        return delta
    }

    private static func isOpeningTag(_ line: String) -> Bool {
        guard line.hasPrefix("<"),
              !line.hasPrefix("</"),
              !line.hasPrefix("<!"),
              !line.hasPrefix("<?"),
              !line.hasSuffix("/>") else {
            return false
        }
        return line.contains(">") && !line.contains("</")
    }
}
