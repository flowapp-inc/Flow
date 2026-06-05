import Foundation

enum LineEnding: String, CaseIterable, Identifiable, Codable {
    case lf
    case crlf
    case cr

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lf: "LF"
        case .crlf: "CRLF"
        case .cr: "CR"
        }
    }

    var sequence: String {
        switch self {
        case .lf: "\n"
        case .crlf: "\r\n"
        case .cr: "\r"
        }
    }

    static func detect(in string: String) -> LineEnding {
        let crlf = string.components(separatedBy: "\r\n").count - 1
        let withoutCRLF = string.replacingOccurrences(of: "\r\n", with: "")
        let lf = withoutCRLF.components(separatedBy: "\n").count - 1
        let cr = withoutCRLF.components(separatedBy: "\r").count - 1

        if crlf >= lf && crlf >= cr && crlf > 0 { return .crlf }
        if cr > lf && cr > 0 { return .cr }
        return .lf
    }
}
