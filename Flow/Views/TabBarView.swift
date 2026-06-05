import SwiftUI
import UniformTypeIdentifiers

struct TabBarView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences
    @State private var draggingDocumentID: UUID?

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(model.documents) { document in
                    TabButton(document: document)
                        .opacity(draggingDocumentID == document.id ? 0.55 : 1)
                        .onDrag {
                            draggingDocumentID = document.id
                            return NSItemProvider(object: document.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [UTType.utf8PlainText],
                            delegate: TabReorderDropDelegate(
                                targetDocumentID: document.id,
                                model: model,
                                draggingDocumentID: $draggingDocumentID
                            )
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .onDrop(of: [UTType.utf8PlainText], isTargeted: nil) { _ in
                model.finishTabReorder()
                draggingDocumentID = nil
                return true
            }
        }
        .frame(height: 36)
        .background(Color(nsColor: theme.background))
    }
}

private struct TabReorderDropDelegate: DropDelegate {
    let targetDocumentID: UUID
    let model: AppModel
    @Binding var draggingDocumentID: UUID?

    func dropEntered(info: DropInfo) {
        model.reorderTab(draggedID: draggingDocumentID, over: targetDocumentID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        model.finishTabReorder()
        draggingDocumentID = nil
        return true
    }

    func dropExited(info: DropInfo) {
        model.finishTabReorder()
    }
}

private struct TabButton: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences
    @ObservedObject var document: EditorDocument

    private var theme: FlowTheme { preferences.theme }
    private var isSelected: Bool { model.selectedDocumentID == document.id }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(nsColor: document.isDirty ? theme.accent : theme.mutedText))
                .frame(width: 14)

            Text(document.title)
                .lineLimit(1)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(Color(nsColor: isSelected ? theme.text : theme.mutedText))
                .frame(maxWidth: 190, alignment: .leading)

            Button {
                model.close(document)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(nsColor: theme.mutedText.withAlpha(isSelected ? 0.95 : 0.72)))
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .help("Close Tab")
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(nsColor: isSelected ? theme.editorSurface : theme.background.withAlpha(0.001)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color(nsColor: isSelected ? theme.gutterText.withAlpha(0.16) : .clear), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .onTapGesture {
            model.select(document)
        }
        .help("Drag to reorder")
    }

    private var iconName: String {
        guard !document.isDirty else { return "circle.fill" }
        if document.kind == .image { return "photo" }
        switch document.displayLanguage {
        case "markdown": return "doc.richtext"
        case "json", "yaml", "toml", "xml", "html": return "curlybraces"
        case "makefile", "dockerfile": return "shippingbox"
        default: return "doc.text"
        }
    }
}
