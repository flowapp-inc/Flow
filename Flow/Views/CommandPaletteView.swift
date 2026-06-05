import SwiftUI

struct CommandPaletteView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences
    @FocusState private var focused: Bool

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            Divider()
                .opacity(theme.isDark ? 0.22 : 0.34)

            resultsList
        }
        .frame(width: 580)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: theme.gutterText.withAlpha(theme.isDark ? 0.20 : 0.16)), lineWidth: 1)
        )
        .shadow(color: .black.opacity(theme.isDark ? 0.34 : 0.14), radius: 26, x: 0, y: 14)
        .onAppear {
            focused = true
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "command")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(nsColor: theme.accent))
                .frame(width: 18)

            TextField("Command", text: $model.commandPaletteQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(nsColor: theme.text))
                .focused($focused)
                .onSubmit {
                    runFirstResult()
                }

            if !model.commandPaletteQuery.isEmpty {
                Button {
                    model.commandPaletteQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(nsColor: theme.mutedText.withAlpha(0.70)))
            }

            Button {
                model.closeCommandPalette()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(CommandPaletteIconButtonStyle(theme: theme))
            .help("Close")
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }

    private var resultsList: some View {
        Group {
            if filteredEntries.isEmpty {
                HStack {
                    Spacer()
                    Text("No commands")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(nsColor: theme.mutedText))
                        .padding(.vertical, 32)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                            Button {
                                run(entry)
                            } label: {
                                CommandPaletteRow(
                                    entry: entry,
                                    isPrimary: index == 0,
                                    theme: theme
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(maxHeight: 340)
    }

    private var filteredEntries: [CommandPaletteEntry] {
        let query = model.commandPaletteQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let entries = allEntries
        guard !query.isEmpty else { return Array(entries.prefix(14)) }

        let parts = query.split(separator: " ").map(String.init)
        return entries
            .filter { entry in
                let haystack = entry.searchText
                return parts.allSatisfy { haystack.contains($0) }
            }
            .prefix(20)
            .map { $0 }
    }

    private var allEntries: [CommandPaletteEntry] {
        var entries: [CommandPaletteEntry] = [
            CommandPaletteEntry(
                id: "file.new",
                title: "New File",
                subtitle: "Create an untitled tab",
                icon: "doc.badge.plus",
                keywords: "create document tab"
            ) {
                model.newDocument()
            },
            CommandPaletteEntry(
                id: "file.open",
                title: "Open File or Folder",
                subtitle: "Choose from disk",
                icon: "folder"
            ) {
                model.openPanel()
            },
            CommandPaletteEntry(
                id: "file.save",
                title: "Save",
                subtitle: model.selectedDocument?.title ?? "Current tab",
                icon: "square.and.arrow.down"
            ) {
                _ = model.saveSelected()
            },
            CommandPaletteEntry(
                id: "file.reload",
                title: "Reload File",
                subtitle: model.selectedDocument?.url?.lastPathComponent ?? "Current tab",
                icon: "arrow.clockwise",
                keywords: "refresh disk"
            ) {
                model.reloadSelectedFromDisk()
            },
            CommandPaletteEntry(
                id: "editor.format",
                title: "Format Document",
                subtitle: model.selectedDocument?.displayLanguage ?? "Current file",
                icon: "text.alignleft",
                keywords: "indent whitespace"
            ) {
                model.formatSelectedDocument()
            },
            CommandPaletteEntry(
                id: "editor.find",
                title: "Search Document",
                subtitle: "Find matches with line previews",
                icon: "magnifyingglass",
                keywords: "find"
            ) {
                model.showDocumentSearch()
            },
            CommandPaletteEntry(
                id: "editor.goto",
                title: "Go to Line",
                subtitle: "Jump by line or line:column",
                icon: "arrow.down.to.line.compact",
                keywords: "jump"
            ) {
                model.showGoToLine()
            },
            CommandPaletteEntry(
                id: "editor.comment",
                title: "Toggle Comment",
                subtitle: "Comment selected lines",
                icon: "text.bubble",
                keywords: "line comment"
            ) {
                model.toggleCommentSelectedDocument()
            },
            CommandPaletteEntry(
                id: "editor.duplicate",
                title: "Duplicate Line or Selection",
                subtitle: "Copy the current line or selected text",
                icon: "plus.square.on.square",
                keywords: "copy clone"
            ) {
                model.duplicateLineOrSelection()
            },
            CommandPaletteEntry(
                id: "editor.trim",
                title: "Trim Trailing Whitespace",
                subtitle: "Clean current document",
                icon: "scissors",
                keywords: "format clean"
            ) {
                model.trimTrailingWhitespace()
            },
            CommandPaletteEntry(
                id: "view.sidebar",
                title: preferences.sidebarVisible ? "Hide Sidebar" : "Show Sidebar",
                subtitle: "Toggle file browser",
                icon: "sidebar.left",
                keywords: "files folder"
            ) {
                preferences.sidebarVisible.toggle()
            },
            CommandPaletteEntry(
                id: "view.minimap",
                title: preferences.showMinimap ? "Hide Minimap" : "Show Minimap",
                subtitle: "Toggle code overview",
                icon: "list.bullet.indent",
                keywords: "overview map"
            ) {
                preferences.showMinimap.toggle()
            },
            CommandPaletteEntry(
                id: "view.wordwrap",
                title: preferences.wordWrap ? "Disable Word Wrap" : "Enable Word Wrap",
                subtitle: "Toggle wrapping globally",
                icon: "text.word.spacing",
                keywords: "wrap"
            ) {
                preferences.wordWrap.toggle()
            },
            CommandPaletteEntry(
                id: "view.lineNumbers",
                title: preferences.showLineNumbers ? "Hide Line Numbers" : "Show Line Numbers",
                subtitle: "Toggle editor gutter",
                icon: "number",
                keywords: "gutter"
            ) {
                preferences.showLineNumbers.toggle()
            }
        ]

        entries.append(contentsOf: FlowTheme.all.map { theme in
            CommandPaletteEntry(
                id: "theme.\(theme.id)",
                title: "Theme: \(theme.name)",
                subtitle: theme.id == preferences.themeID ? "Current theme" : "Switch appearance",
                icon: theme.isDark ? "moon" : "sun.max",
                keywords: "appearance color palette"
            ) {
                preferences.themeID = theme.id
            }
        })

        let recentEntries = preferences.recentBookmarks
            .compactMap(BookmarkStore.resolve)
            .prefix(8)
            .map { url in
                CommandPaletteEntry(
                    id: "recent.\(url.path)",
                    title: "Open Recent: \(url.lastPathComponent)",
                    subtitle: url.deletingLastPathComponent().path,
                    icon: "clock.arrow.circlepath",
                    keywords: "history file"
                ) {
                    model.openFile(url)
                }
            }
        entries.append(contentsOf: recentEntries)
        return entries
    }

    private func runFirstResult() {
        guard let first = filteredEntries.first else { return }
        run(first)
    }

    private func run(_ entry: CommandPaletteEntry) {
        model.closeCommandPalette()
        entry.action()
    }

    private var panelBackground: some View {
        Color(nsColor: theme.background.blended(withFraction: theme.isDark ? 0.10 : 0.04, of: theme.editorSurface) ?? theme.background)
    }
}

private struct CommandPaletteEntry: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let keywords: String
    let action: () -> Void

    init(
        id: String,
        title: String,
        subtitle: String,
        icon: String,
        keywords: String = "",
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.keywords = keywords
        self.action = action
    }

    var searchText: String {
        "\(title) \(subtitle) \(keywords)".lowercased()
    }
}

private struct CommandPaletteRow: View {
    let entry: CommandPaletteEntry
    let isPrimary: Bool
    let theme: FlowTheme

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: entry.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(nsColor: isPrimary ? theme.accent : theme.mutedText))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(nsColor: theme.text))
                    .lineLimit(1)

                Text(entry.subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: theme.mutedText))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isPrimary {
                Image(systemName: "return")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(nsColor: theme.mutedText))
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: isPrimary ? theme.selection : theme.editorSurface.withAlpha(0.001)))
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CommandPaletteIconButtonStyle: ButtonStyle {
    let theme: FlowTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(nsColor: theme.text))
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: configuration.isPressed ? theme.selection : theme.editorSurface.withAlpha(0.001)))
            )
    }
}
