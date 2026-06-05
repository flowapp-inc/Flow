import SwiftUI

struct FileBrowserView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences

    @State private var nodes: [FileNode] = []
    @State private var expandedFolders: Set<URL> = []

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let root = model.sidebarRoot {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(nodes) { node in
                            FileTreeRow(node: node, depth: 0, expandedFolders: $expandedFolders)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .onAppear { reload(root: root) }
                .onChange(of: model.fileBrowserRefreshID) { _, _ in reload(root: root) }
                .onChange(of: root) { _, newRoot in reload(root: newRoot) }
            } else {
                VStack(spacing: 12) {
                    Button("Open Folder") {
                        model.openFolderPanel()
                    }
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: theme.background))
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.sidebarRoot?.lastPathComponent ?? "Files")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(nsColor: theme.text))
                    .lineLimit(1)
                Text(model.sidebarRoot?.path ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(nsColor: theme.mutedText))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                model.openFolderPanel()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(FlowIconButtonStyle(theme: theme))
            .help("Open Folder")

            Button {
                model.createFile(in: model.sidebarRoot)
            } label: {
                Image(systemName: "doc.badge.plus")
            }
            .buttonStyle(FlowIconButtonStyle(theme: theme))
            .help("New File")

            Button {
                model.createFolder(in: model.sidebarRoot)
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(FlowIconButtonStyle(theme: theme))
            .help("New Folder")
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(Color(nsColor: theme.background))
    }

    private func reload(root: URL) {
        nodes = FileNode.load(root: root)
        expandedFolders.insert(root)
    }

    private func iconName(for node: FileNode) -> String {
        guard !node.isDirectory else { return "folder" }
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

private struct FileTreeRow: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences

    let node: FileNode
    let depth: Int
    @Binding var expandedFolders: Set<URL>

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button {
                if node.isDirectory {
                    toggleFolder(node.url)
                } else {
                    model.openFile(node.url)
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: disclosureIcon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(nsColor: theme.mutedText))
                        .frame(width: 10)
                        .opacity(node.isDirectory ? 1 : 0)

                    Image(systemName: iconName)
                        .foregroundStyle(Color(nsColor: node.isDirectory ? theme.accent : theme.mutedText))
                        .frame(width: 14)

                    Text(node.name)
                        .lineLimit(1)
                        .foregroundStyle(Color(nsColor: theme.text))
                    Spacer(minLength: 0)
                }
                .font(.system(size: 12))
                .padding(.leading, CGFloat(depth) * 14)
                .padding(.horizontal, 8)
                .frame(height: 25)
                .contentShape(RoundedRectangle(cornerRadius: 6))
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: isSelected ? theme.selection.withAlpha(0.18) : theme.background.withAlpha(0.001)))
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                if node.isDirectory {
                    Button("New File") { model.createFile(in: node.url) }
                    Button("New Folder") { model.createFolder(in: node.url) }
                    Divider()
                }
                Button("Rename") { model.renameItem(node.url) }
                Button("Delete") { model.deleteItem(node.url) }
            }

            if node.isDirectory, expandedFolders.contains(node.url), let children = node.children {
                ForEach(children) { child in
                    FileTreeRow(node: child, depth: depth + 1, expandedFolders: $expandedFolders)
                }
            }
        }
    }

    private var disclosureIcon: String {
        expandedFolders.contains(node.url) ? "chevron.down" : "chevron.right"
    }

    private func toggleFolder(_ url: URL) {
        if expandedFolders.contains(url) {
            expandedFolders.remove(url)
        } else {
            expandedFolders.insert(url)
        }
    }

    private var iconName: String {
        guard !node.isDirectory else { return "folder" }
        let language = LanguageDetector.detectLanguage(for: node.url, contents: "")
        switch language {
        case "markdown": return "doc.richtext"
        case "json", "yaml", "toml", "xml", "html": return "curlybraces"
        case "makefile", "dockerfile": return "shippingbox"
        case "swift": return "swift"
        default: return "doc.text"
        }
    }

    private var isSelected: Bool {
        guard !node.isDirectory else { return false }
        return model.selectedDocument?.url?.standardizedFileURL == node.url.standardizedFileURL
    }
}
