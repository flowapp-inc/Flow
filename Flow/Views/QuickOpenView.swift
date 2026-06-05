import SwiftUI

struct QuickOpenView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences
    @FocusState private var focused: Bool

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color(nsColor: theme.mutedText))
                TextField("Open file", text: $model.quickOpenQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .focused($focused)
                    .onSubmit {
                        if let first = model.quickOpenResults.first {
                            model.openFromQuickOpen(first)
                        }
                    }
                Button {
                    model.quickOpenVisible = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(nsColor: theme.mutedText))
            }
            .padding(.horizontal, 14)
            .frame(height: 46)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(model.quickOpenResults) { node in
                        Button {
                            model.openFromQuickOpen(node)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: iconName(for: node))
                                    .frame(width: 16)
                                    .foregroundStyle(Color(nsColor: theme.mutedText))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(node.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color(nsColor: theme.text))
                                    Text(node.url.deletingLastPathComponent().path)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color(nsColor: theme.mutedText))
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .contentShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 320)
        }
        .frame(width: 560)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: theme.background))
                .shadow(color: .black.opacity(theme.isDark ? 0.36 : 0.16), radius: 24, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: theme.gutterText.withAlpha(0.18)), lineWidth: 1)
        )
        .onAppear { focused = true }
    }

    private func iconName(for node: FileNode) -> String {
        let language = LanguageDetector.detectLanguage(for: node.url, contents: "")
        switch language {
        case "markdown": return "doc.richtext"
        case "json", "yaml", "toml", "xml", "html": return "curlybraces"
        case "makefile", "dockerfile": return "shippingbox"
        case "swift": return "swift"
        default: return "doc.text"
        }
    }
}
