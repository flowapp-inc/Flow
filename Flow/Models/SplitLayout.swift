import Foundation

enum SplitLayout: String, CaseIterable, Identifiable {
    case none
    case vertical
    case horizontal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "No Split"
        case .vertical: "Vertical Split"
        case .horizontal: "Horizontal Split"
        }
    }
}
