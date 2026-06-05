import AppKit

enum SyntaxRegexHighlighter {
    static func apply(
        to textStorage: NSTextStorage,
        text: String,
        range: NSRange,
        language: String?,
        theme: FlowTheme
    ) {
        guard range.length > 0, let language else { return }

        switch language {
        case "markdown", "asciidoc":
            applyMarkdown(to: textStorage, text: text, range: range, theme: theme)
        case "json", "yaml", "toml", "ini", "properties":
            applyConfig(to: textStorage, text: text, range: range, theme: theme)
        case "makefile":
            applyMakefile(to: textStorage, text: text, range: range, theme: theme)
        case "dockerfile":
            applyDockerfile(to: textStorage, text: text, range: range, theme: theme)
        case "bash", "zsh", "powershell", "dos":
            applyShell(to: textStorage, text: text, range: range, theme: theme)
        default:
            applyCode(to: textStorage, text: text, range: range, language: language, theme: theme)
        }
    }

    private static func applyMarkdown(to storage: NSTextStorage, text: String, range: NSRange, theme: FlowTheme) {
        apply(#"^#{1,6}\s+.*$"#, to: storage, text: text, range: range, color: theme.syntax.keywordColor, options: [.anchorsMatchLines])
        apply(#"`[^`\n]+`"#, to: storage, text: text, range: range, color: theme.syntax.typeColor)
        apply(#"\[[^\]]+\]\([^)]+\)"#, to: storage, text: text, range: range, color: theme.syntax.functionColor)
        apply(#"^\s*[-*+]\s+"#, to: storage, text: text, range: range, color: theme.syntax.operatorNSColor, options: [.anchorsMatchLines])
        apply(#"^>\s?.*$"#, to: storage, text: text, range: range, color: theme.syntax.commentColor, options: [.anchorsMatchLines])
    }

    private static func applyConfig(to storage: NSTextStorage, text: String, range: NSRange, theme: FlowTheme) {
        apply(#""(?:\\.|[^"\\])*""#, to: storage, text: text, range: range, color: theme.syntax.stringColor)
        apply(#"\b-?(?:0|[1-9]\d*)(?:\.\d+)?\b"#, to: storage, text: text, range: range, color: theme.syntax.numberColor)
        apply(#"^\s*[\w.-]+\s*(?=[:=])"#, to: storage, text: text, range: range, color: theme.syntax.keywordColor, options: [.anchorsMatchLines])
        apply(#"^\s*[#;].*$"#, to: storage, text: text, range: range, color: theme.syntax.commentColor, options: [.anchorsMatchLines])
    }

    private static func applyMakefile(to storage: NSTextStorage, text: String, range: NSRange, theme: FlowTheme) {
        apply(#"^\s*[A-Za-z0-9_.%/-]+(?=\s*:)"#, to: storage, text: text, range: range, color: theme.syntax.functionColor, options: [.anchorsMatchLines])
        apply(#"\$\([^)]+\)|\$\{[^}]+\}"#, to: storage, text: text, range: range, color: theme.syntax.typeColor)
        apply(#"^\s*(include|export|override|define|endef|ifeq|ifneq|ifdef|ifndef|else|endif)\b"#, to: storage, text: text, range: range, color: theme.syntax.keywordColor, options: [.anchorsMatchLines])
        apply(#"#.*$"#, to: storage, text: text, range: range, color: theme.syntax.commentColor, options: [.anchorsMatchLines])
    }

    private static func applyDockerfile(to storage: NSTextStorage, text: String, range: NSRange, theme: FlowTheme) {
        apply(#"^\s*(FROM|RUN|CMD|LABEL|MAINTAINER|EXPOSE|ENV|ADD|COPY|ENTRYPOINT|VOLUME|USER|WORKDIR|ARG|ONBUILD|STOPSIGNAL|HEALTHCHECK|SHELL)\b"#, to: storage, text: text, range: range, color: theme.syntax.keywordColor, options: [.anchorsMatchLines, .caseInsensitive])
        apply(#""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, to: storage, text: text, range: range, color: theme.syntax.stringColor)
        apply(#"#.*$"#, to: storage, text: text, range: range, color: theme.syntax.commentColor, options: [.anchorsMatchLines])
    }

    private static func applyShell(to storage: NSTextStorage, text: String, range: NSRange, theme: FlowTheme) {
        apply(#""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, to: storage, text: text, range: range, color: theme.syntax.stringColor)
        apply(#"\b(if|then|else|elif|fi|for|while|do|done|case|esac|function|return|exit|export|local|set|readonly|trap|in)\b"#, to: storage, text: text, range: range, color: theme.syntax.keywordColor)
        apply(#"\$[A-Za-z_][A-Za-z0-9_]*|\$\{[^}]+\}"#, to: storage, text: text, range: range, color: theme.syntax.typeColor)
        apply(#"#.*$"#, to: storage, text: text, range: range, color: theme.syntax.commentColor, options: [.anchorsMatchLines])
    }

    private static func applyCode(to storage: NSTextStorage, text: String, range: NSRange, language: String, theme: FlowTheme) {
        apply(#"^\s*#\s*(include|define|ifdef|ifndef|endif|if|else|elif|pragma|undef|error|warning)\b"#, to: storage, text: text, range: range, color: theme.syntax.keywordColor, options: [.anchorsMatchLines])
        apply(#"<[A-Za-z0-9_./+-]+\.h>"#, to: storage, text: text, range: range, color: theme.syntax.stringColor)
        apply(#""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, to: storage, text: text, range: range, color: theme.syntax.stringColor)
        apply(#"\b-?(?:0x[0-9a-fA-F]+|(?:0|[1-9]\d*)(?:\.\d+)?)\b"#, to: storage, text: text, range: range, color: theme.syntax.numberColor)
        apply(keywordPattern(for: language), to: storage, text: text, range: range, color: theme.syntax.keywordColor)
        apply(typePattern(for: language), to: storage, text: text, range: range, color: theme.syntax.typeColor)
        apply(#"\b[A-Za-z_][A-Za-z0-9_]*(?=\s*\()"#, to: storage, text: text, range: range, color: theme.syntax.functionColor)
        apply(#"//.*$"#, to: storage, text: text, range: range, color: theme.syntax.commentColor, options: [.anchorsMatchLines])
        apply(#"/\*.*?\*/"#, to: storage, text: text, range: range, color: theme.syntax.commentColor, options: [.dotMatchesLineSeparators])
        if ["python", "ruby", "perl", "r", "julia"].contains(language) {
            apply(#"#.*$"#, to: storage, text: text, range: range, color: theme.syntax.commentColor, options: [.anchorsMatchLines])
        }
    }

    private static func keywordPattern(for language: String) -> String {
        switch language {
        case "python":
            return #"\b(and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield|True|False|None)\b"#
        case "swift":
            return #"\b(associatedtype|class|deinit|enum|extension|fileprivate|func|import|init|inout|internal|let|open|operator|private|protocol|public|static|struct|subscript|typealias|var|break|case|catch|continue|default|defer|do|else|fallthrough|for|guard|if|in|repeat|return|switch|throw|try|where|while|as|Any|false|is|nil|rethrows|self|Self|super|throws|true)\b"#
        case "rust":
            return #"\b(as|async|await|break|const|continue|crate|dyn|else|enum|extern|false|fn|for|if|impl|in|let|loop|match|mod|move|mut|pub|ref|return|self|Self|static|struct|super|trait|true|type|unsafe|use|where|while)\b"#
        default:
            return #"\b(auto|break|case|catch|class|const|continue|default|delete|do|else|enum|extern|false|for|goto|if|import|include|inline|interface|namespace|new|null|nullptr|private|protected|public|return|sizeof|static|struct|switch|template|this|throw|true|try|typedef|typename|union|using|virtual|void|volatile|while|let|var|function|await|async|yield|static|register|restrict)\b"#
        }
    }

    private static func typePattern(for language: String) -> String {
        switch language {
        case "swift":
            return #"\b(String|Int|Double|Float|Bool|Character|Array|Dictionary|Set|Optional|Result|URL|UUID|Data|Date)\b"#
        case "python":
            return #"\b(str|int|float|bool|list|dict|set|tuple|object|Exception|Path|Any|Optional|Callable)\b"#
        default:
            return #"\b(bool|char|double|float|int|long|short|signed|unsigned|void|size_t|ssize_t|uintptr_t|intptr_t|uint8_t|uint16_t|uint32_t|uint64_t|int8_t|int16_t|int32_t|int64_t|string|String|Boolean|Number|Object|Array|Map|Set|List|Dict)\b"#
        }
    }

    private static func apply(
        _ pattern: String,
        to storage: NSTextStorage,
        text: String,
        range: NSRange,
        color: NSColor,
        options: NSRegularExpression.Options = []
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match, match.range.location != NSNotFound, NSMaxRange(match.range) <= storage.length else { return }
            storage.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}
