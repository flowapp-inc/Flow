import AppKit
import SwiftUI

extension NSColor {
    convenience init(hex: String, alpha: CGFloat = 1) {
        var value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }

        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)

        let red = CGFloat((int >> 16) & 0xff) / 255
        let green = CGFloat((int >> 8) & 0xff) / 255
        let blue = CGFloat(int & 0xff) / 255
        self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    func withAlpha(_ alpha: CGFloat) -> NSColor {
        withAlphaComponent(alpha)
    }
}

extension Color {
    init(hex: String, alpha: CGFloat = 1) {
        self.init(nsColor: NSColor(hex: hex, alpha: alpha))
    }
}

extension String {
    var nsRange: NSRange {
        NSRange(startIndex..<endIndex, in: self)
    }

    func lineEndingNormalized(to replacement: String) -> String {
        replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: replacement)
    }
}

extension String.Encoding {
    var localizedName: String {
        switch self {
        case .utf8: "UTF-8"
        case .utf16: "UTF-16"
        case .utf16LittleEndian: "UTF-16 LE"
        case .utf16BigEndian: "UTF-16 BE"
        case .utf32: "UTF-32"
        case .utf32LittleEndian: "UTF-32 LE"
        case .utf32BigEndian: "UTF-32 BE"
        case .isoLatin1: "Latin-1"
        case .windowsCP1252: "Windows-1252"
        case .macOSRoman: "Mac Roman"
        default: "Encoding \(rawValue)"
        }
    }
}

extension Notification.Name {
    static let flowOpenFiles = Notification.Name("FlowOpenFilesNotification")
}
