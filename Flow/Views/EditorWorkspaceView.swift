import SwiftUI

struct EditorWorkspaceView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        Group {
            if model.documents.isEmpty {
                EmptyEditorView()
            } else {
                switch model.splitLayout {
                case .none:
                    if let document = model.selectedDocument {
                        EditorPaneView(document: document, pane: .primary)
                    }
                case .vertical:
                    ResizableEditorSplit(layout: .vertical, ratio: $preferences.splitRatio, theme: theme) {
                        if let document = model.selectedDocument {
                            EditorPaneView(document: document, pane: .primary)
                        }
                    } secondary: {
                        if let document = model.secondaryDocument {
                            EditorPaneView(document: document, pane: .secondary)
                        }
                    }
                case .horizontal:
                    ResizableEditorSplit(layout: .horizontal, ratio: $preferences.splitRatio, theme: theme) {
                        if let document = model.selectedDocument {
                            EditorPaneView(document: document, pane: .primary)
                        }
                    } secondary: {
                        if let document = model.secondaryDocument {
                            EditorPaneView(document: document, pane: .secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct ResizableEditorSplit<Primary: View, Secondary: View>: View {
    let layout: SplitLayout
    @Binding var ratio: Double
    let theme: FlowTheme
    let primary: Primary
    let secondary: Secondary

    @State private var dragStartRatio: Double?
    @State private var liveRatio: Double?

    private let dividerThickness: CGFloat = 8
    private var displayedRatio: Double { liveRatio ?? ratio }

    init(
        layout: SplitLayout,
        ratio: Binding<Double>,
        theme: FlowTheme,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder secondary: () -> Secondary
    ) {
        self.layout = layout
        _ratio = ratio
        self.theme = theme
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        GeometryReader { proxy in
            let isVertical = layout == .vertical
            let totalLength = max(1, isVertical ? proxy.size.width : proxy.size.height)
            let usableLength = max(1, totalLength - dividerThickness)
            let primaryLength = usableLength * CGFloat(displayedRatio)
            let secondaryLength = max(0, usableLength - primaryLength)

            Group {
                if isVertical {
                    HStack(spacing: 0) {
                        primary
                            .frame(width: primaryLength, height: proxy.size.height)
                        SplitDivider(layout: layout, theme: theme)
                            .frame(width: dividerThickness, height: proxy.size.height)
                            .highPriorityGesture(dragGesture(usableLength: usableLength))
                        secondary
                            .frame(width: secondaryLength, height: proxy.size.height)
                    }
                } else {
                    VStack(spacing: 0) {
                        primary
                            .frame(width: proxy.size.width, height: primaryLength)
                        SplitDivider(layout: layout, theme: theme)
                            .frame(width: proxy.size.width, height: dividerThickness)
                            .highPriorityGesture(dragGesture(usableLength: usableLength))
                        secondary
                            .frame(width: proxy.size.width, height: secondaryLength)
                    }
                }
            }
            .background(Color(nsColor: theme.editorSurface))
            .transaction { transaction in
                transaction.animation = nil
            }
        }
    }

    private func dragGesture(usableLength: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartRatio == nil {
                    dragStartRatio = ratio
                }

                let delta = layout == .vertical ? value.translation.width : value.translation.height
                let next = (dragStartRatio ?? displayedRatio) + Double(delta / usableLength)
                liveRatio = clampedRatio(next)
            }
            .onEnded { _ in
                if let liveRatio {
                    ratio = liveRatio
                }
                dragStartRatio = nil
                liveRatio = nil
            }
    }

    private func clampedRatio(_ value: Double) -> Double {
        min(0.82, max(0.18, value))
    }
}

private struct SplitDivider: View {
    let layout: SplitLayout
    let theme: FlowTheme

    @State private var isHovering = false

    var body: some View {
        ZStack {
            Color(nsColor: theme.background)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(nsColor: theme.gutterText.withAlpha(isHovering ? 0.48 : 0.18)))
                .frame(width: layout == .vertical ? 1.5 : 34, height: layout == .vertical ? 34 : 1.5)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                (layout == .vertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
            } else {
                NSCursor.pop()
            }
        }
        .help("Drag to resize split")
    }
}

enum EditorPaneRole {
    case primary
    case secondary
}

struct EditorPaneView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences
    @ObservedObject var document: EditorDocument

    let pane: EditorPaneRole

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        VStack(spacing: 0) {
            PaneHeaderView(document: document, pane: pane)
            if document.kind == .image {
                ImageViewerView(document: document)
            } else {
                CodeEditorView(document: document, preferences: preferences, theme: theme) {
                    model.scheduleFindRangeUpdate()
                }
                .background(Color(nsColor: theme.background))
            }
        }
        .onReceive(document.$text) { _ in
            model.scheduleFindRangeUpdate()
            model.scheduleDocumentSearch()
        }
    }
}

private struct PaneHeaderView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences
    @ObservedObject var document: EditorDocument

    let pane: EditorPaneRole

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(nsColor: theme.mutedText))
                .frame(width: 16)

            if model.splitLayout == .none {
                titleBlock
            } else {
                Menu {
                    ForEach(model.documents) { item in
                        Button(item.title) {
                            documentBinding.wrappedValue = item.id
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(document.title)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(nsColor: theme.text))
                }
                .buttonStyle(.plain)
                .menuStyle(.borderlessButton)
            }

            Spacer()

            if document.kind == .text {
                Menu {
                    Button("Auto (\(document.detectedLanguage ?? "plaintext"))") {
                        document.languageOverride = nil
                    }
                    Divider()
                    ForEach(LanguageDetector.menuLanguages, id: \.self) { language in
                        Button(language) {
                            document.languageOverride = language == "plaintext" ? nil : language
                        }
                    }
                } label: {
                    Text(document.displayLanguage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(nsColor: theme.mutedText))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 100)
                .help("Language")

                Menu {
                    ForEach(LineEnding.allCases) { lineEnding in
                        Button(lineEnding.label) {
                            document.lineEnding = lineEnding
                        }
                    }
                } label: {
                    Text(document.lineEnding.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(nsColor: theme.mutedText))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 50)
                .help("Line Endings")

                Button {
                    document.wordWrapOverride = !(document.wordWrapOverride ?? preferences.wordWrap)
                } label: {
                    Image(systemName: (document.wordWrapOverride ?? preferences.wordWrap) ? "text.word.spacing" : "arrow.left.and.right.text.vertical")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(nsColor: theme.mutedText))
                .help("Toggle Word Wrap")
            } else {
                Text(document.displayLanguage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(nsColor: theme.mutedText))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color(nsColor: theme.background))
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(document.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(nsColor: theme.text))
                .lineLimit(1)
            Text(document.subtitle)
                .font(.system(size: 10))
                .foregroundStyle(Color(nsColor: theme.mutedText))
                .lineLimit(1)
        }
    }

    private var iconName: String {
        if document.kind == .image { return "photo" }
        switch document.displayLanguage {
        case "markdown": return "doc.richtext"
        case "json", "yaml", "toml", "xml", "html": return "curlybraces"
        case "makefile", "dockerfile": return "shippingbox"
        default: return "doc.text"
        }
    }

    private var documentBinding: Binding<UUID> {
        Binding {
            pane == .primary ? (model.selectedDocumentID ?? document.id) : (model.secondaryDocumentID ?? document.id)
        } set: { id in
            if pane == .primary {
                model.selectedDocumentID = id
            } else {
                model.secondaryDocumentID = id
            }
        }
    }
}

private struct EmptyEditorView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        VStack(spacing: 14) {
            Text("Flow")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color(nsColor: theme.text))
            HStack(spacing: 10) {
                Button("New File") {
                    model.newDocument()
                }
                Button("Open...") {
                    model.openPanel()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: theme.editorSurface))
    }
}
