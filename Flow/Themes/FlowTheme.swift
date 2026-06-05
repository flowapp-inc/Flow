import AppKit
import SwiftUI

struct SyntaxPalette: Equatable {
    let keyword: String
    let string: String
    let number: String
    let comment: String
    let type: String
    let function: String
    let operatorColor: String

    var keywordColor: NSColor { NSColor(hex: keyword) }
    var stringColor: NSColor { NSColor(hex: string) }
    var numberColor: NSColor { NSColor(hex: number) }
    var commentColor: NSColor { NSColor(hex: comment) }
    var typeColor: NSColor { NSColor(hex: type) }
    var functionColor: NSColor { NSColor(hex: function) }
    var operatorNSColor: NSColor { NSColor(hex: operatorColor) }
}

struct FlowTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let highlightrTheme: String
    let isDark: Bool
    let backgroundHex: String
    let editorSurfaceHex: String
    let textHex: String
    let mutedTextHex: String
    let gutterHex: String
    let gutterTextHex: String
    let selectionHex: String
    let lineHighlightHex: String
    let cursorHex: String
    let minimapHex: String
    let minimapTextHex: String
    let accentHex: String
    let syntax: SyntaxPalette

    var background: NSColor { NSColor(hex: backgroundHex) }
    var editorSurface: NSColor { NSColor(hex: editorSurfaceHex) }
    var text: NSColor { NSColor(hex: textHex) }
    var mutedText: NSColor { NSColor(hex: mutedTextHex) }
    var gutter: NSColor { NSColor(hex: gutterHex) }
    var gutterText: NSColor { NSColor(hex: gutterTextHex) }
    var selection: NSColor { NSColor(hex: selectionHex, alpha: isDark ? 0.45 : 0.35) }
    var lineHighlight: NSColor { NSColor(hex: lineHighlightHex, alpha: isDark ? 0.55 : 0.65) }
    var cursor: NSColor { NSColor(hex: cursorHex) }
    var minimap: NSColor { NSColor(hex: minimapHex) }
    var minimapText: NSColor { NSColor(hex: minimapTextHex) }
    var accent: NSColor { NSColor(hex: accentHex) }

    var colorScheme: ColorScheme { isDark ? .dark : .light }
    var swiftBackground: Color { Color(nsColor: background) }
    var swiftEditorSurface: Color { Color(nsColor: editorSurface) }
    var swiftText: Color { Color(nsColor: text) }
    var swiftMutedText: Color { Color(nsColor: mutedText) }
    var swiftAccent: Color { Color(nsColor: accent) }

    static let all: [FlowTheme] = [
        FlowTheme(
            id: "flowLight",
            name: "Flow Light",
            highlightrTheme: "github",
            isDark: false,
            backgroundHex: "F8F9FB",
            editorSurfaceHex: "FFFFFF",
            textHex: "1E2329",
            mutedTextHex: "667085",
            gutterHex: "FFFFFF",
            gutterTextHex: "9AA4B2",
            selectionHex: "7CB7FF",
            lineHighlightHex: "F1F5FA",
            cursorHex: "0B57D0",
            minimapHex: "F7F9FC",
            minimapTextHex: "A8B0BD",
            accentHex: "2563EB",
            syntax: SyntaxPalette(
                keyword: "A626A4",
                string: "0B6B50",
                number: "986801",
                comment: "8C97A5",
                type: "1E6BB8",
                function: "305CAD",
                operatorColor: "3D4752"
            )
        ),
        FlowTheme(
            id: "flowDark",
            name: "Flow Dark",
            highlightrTheme: "atom-one-dark",
            isDark: true,
            backgroundHex: "111315",
            editorSurfaceHex: "15181C",
            textHex: "E9EDF2",
            mutedTextHex: "8F99A8",
            gutterHex: "111315",
            gutterTextHex: "5D6673",
            selectionHex: "3A6EA5",
            lineHighlightHex: "1C2026",
            cursorHex: "9CDCFE",
            minimapHex: "111315",
            minimapTextHex: "58606B",
            accentHex: "61AFEF",
            syntax: SyntaxPalette(
                keyword: "C678DD",
                string: "98C379",
                number: "D19A66",
                comment: "5C6370",
                type: "E5C07B",
                function: "61AFEF",
                operatorColor: "56B6C2"
            )
        ),
        FlowTheme(
            id: "tokyoNight",
            name: "Tokyo Night",
            highlightrTheme: "tokyo-night-dark",
            isDark: true,
            backgroundHex: "1A1B26",
            editorSurfaceHex: "1F2335",
            textHex: "C0CAF5",
            mutedTextHex: "7AA2F7",
            gutterHex: "1A1B26",
            gutterTextHex: "565F89",
            selectionHex: "33467C",
            lineHighlightHex: "24283B",
            cursorHex: "C0CAF5",
            minimapHex: "16161E",
            minimapTextHex: "565F89",
            accentHex: "7AA2F7",
            syntax: SyntaxPalette(
                keyword: "BB9AF7",
                string: "9ECE6A",
                number: "FF9E64",
                comment: "565F89",
                type: "2AC3DE",
                function: "7AA2F7",
                operatorColor: "89DDFF"
            )
        ),
        FlowTheme(
            id: "solarizedLight",
            name: "Solarized Light",
            highlightrTheme: "solarized-light",
            isDark: false,
            backgroundHex: "FDF6E3",
            editorSurfaceHex: "FFF9E8",
            textHex: "586E75",
            mutedTextHex: "93A1A1",
            gutterHex: "FDF6E3",
            gutterTextHex: "93A1A1",
            selectionHex: "B3D7D6",
            lineHighlightHex: "EEE8D5",
            cursorHex: "268BD2",
            minimapHex: "F5EFD9",
            minimapTextHex: "93A1A1",
            accentHex: "268BD2",
            syntax: SyntaxPalette(
                keyword: "859900",
                string: "2AA198",
                number: "D33682",
                comment: "93A1A1",
                type: "B58900",
                function: "268BD2",
                operatorColor: "657B83"
            )
        ),
        FlowTheme(
            id: "solarizedDark",
            name: "Solarized Dark",
            highlightrTheme: "solarized-dark",
            isDark: true,
            backgroundHex: "002B36",
            editorSurfaceHex: "06313C",
            textHex: "A9B8BA",
            mutedTextHex: "71878B",
            gutterHex: "002B36",
            gutterTextHex: "60777C",
            selectionHex: "256B7A",
            lineHighlightHex: "0A3A46",
            cursorHex: "93A1A1",
            minimapHex: "002631",
            minimapTextHex: "60777C",
            accentHex: "268BD2",
            syntax: SyntaxPalette(
                keyword: "859900",
                string: "2AA198",
                number: "D33682",
                comment: "586E75",
                type: "B58900",
                function: "268BD2",
                operatorColor: "93A1A1"
            )
        ),
        FlowTheme(
            id: "monokai",
            name: "Monokai",
            highlightrTheme: "monokai-sublime",
            isDark: true,
            backgroundHex: "272822",
            editorSurfaceHex: "2D2E28",
            textHex: "F8F8F2",
            mutedTextHex: "A6A895",
            gutterHex: "272822",
            gutterTextHex: "75715E",
            selectionHex: "49483E",
            lineHighlightHex: "303129",
            cursorHex: "F8F8F0",
            minimapHex: "20211C",
            minimapTextHex: "75715E",
            accentHex: "A6E22E",
            syntax: SyntaxPalette(
                keyword: "F92672",
                string: "E6DB74",
                number: "AE81FF",
                comment: "75715E",
                type: "66D9EF",
                function: "A6E22E",
                operatorColor: "F92672"
            )
        )
    ]

    static func theme(with id: String) -> FlowTheme {
        all.first { $0.id == id } ?? all[1]
    }
}
