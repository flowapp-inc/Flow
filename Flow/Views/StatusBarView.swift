import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences

    private var theme: FlowTheme { preferences.theme }
    private var document: EditorDocument? { model.selectedDocument }

    var body: some View {
        HStack(spacing: 12) {
            Text(model.statusMessage)
                .lineLimit(1)

            Spacer()

            if let document {
                if document.kind == .image {
                    if let size = document.imagePixelSize {
                        Text("\(Int(size.width)) x \(Int(size.height))")
                    }
                    Text(ByteCountFormatter.string(fromByteCount: Int64(document.byteCount), countStyle: .file))
                    Text(document.imageFormat ?? "image")
                    Text("view-only")
                } else {
                    Text(cursorLabel(for: document))
                    Text("\(document.lineCount) lines")
                    if document.largeFileModeEnabled {
                        Text("Large File Mode")
                            .foregroundStyle(Color(nsColor: theme.accent))
                    }
                    Text(document.displayLanguage)
                    Text(document.encoding.localizedName)
                    Text(document.lineEnding.label)
                }
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(Color(nsColor: theme.mutedText))
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(Color(nsColor: theme.background))
    }

    private func cursorLabel(for document: EditorDocument) -> String {
        guard document.kind == .text else { return "" }
        let nsText = document.text as NSString
        let location = min(document.selectionRange.location, nsText.length)
        let prefix = nsText.substring(to: location)
        let line = prefix.components(separatedBy: "\n").count
        let lineStart = (prefix as NSString).range(of: "\n", options: .backwards).location
        let column: Int
        if lineStart == NSNotFound {
            column = (prefix as NSString).length + 1
        } else {
            column = (prefix as NSString).length - lineStart
        }
        return "Ln \(line), Col \(column)"
    }
}
