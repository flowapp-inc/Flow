import SwiftUI

struct FlowCommands: Commands {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: EditorPreferences

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New File") {
                model.newDocument()
            }
            .keyboardShortcut("n")

            Button("Open...") {
                model.openPanel()
            }
            .keyboardShortcut("o")

            Button("Open Folder...") {
                model.openFolderPanel()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            Button("Copy File Path") {
                model.copySelectedPath()
            }
            .keyboardShortcut("c", modifiers: [.command, .option])

            Button("Reveal in Finder") {
                model.revealSelectedInFinder()
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
        }

        CommandGroup(after: .saveItem) {
            Button("Save") {
                model.saveSelected()
            }
            .keyboardShortcut("s")

            Button("Save As...") {
                model.saveAsSelected()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("Save All") {
                model.saveAll()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])

            Button("Reload from Disk") {
                model.reloadSelectedFromDisk()
            }
            .keyboardShortcut("r", modifiers: [.command, .option])

            Button("Close Tab") {
                model.closeSelectedTab()
            }
            .keyboardShortcut("w")
        }

        CommandMenu("Editor") {
            Button("Quick Open") {
                model.toggleQuickOpen()
            }
            .keyboardShortcut("p")

            Button("Command Palette") {
                model.showCommandPalette()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Divider()

            Button("Find") {
                model.findPanelVisible = true
                model.updateFindRanges()
            }
            .keyboardShortcut("f")

            Button("Search Document") {
                model.showDocumentSearch()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button("Find Next") {
                model.findNext()
            }
            .keyboardShortcut("g")

            Button("Find Previous") {
                model.findPrevious()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Divider()

            Button("Go to Line") {
                model.showGoToLine()
            }
            .keyboardShortcut("l", modifiers: [.command])

            Divider()

            Button("Format Document") {
                model.formatSelectedDocument()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button("Toggle Comment") {
                model.toggleCommentSelectedDocument()
            }
            .keyboardShortcut("/", modifiers: [.command])

            Button("Duplicate Line or Selection") {
                model.duplicateLineOrSelection()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Trim Trailing Whitespace") {
                model.trimTrailingWhitespace()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Divider()

            Toggle("Line Numbers", isOn: $preferences.showLineNumbers)
            Toggle("Word Wrap", isOn: $preferences.wordWrap)
            Toggle("Minimap", isOn: $preferences.showMinimap)
        }

        CommandMenu("View") {
            Toggle("Sidebar", isOn: $preferences.sidebarVisible)
                .keyboardShortcut("s", modifiers: [.command, .control])

            Divider()

            Button("Vertical Split") {
                model.toggleSplit(.vertical)
            }
            .keyboardShortcut("\\", modifiers: [.command])

            Button("Horizontal Split") {
                model.toggleSplit(.horizontal)
            }
            .keyboardShortcut("\\", modifiers: [.command, .shift])

            Button("Close Split") {
                model.toggleSplit(.none)
            }
            .keyboardShortcut("0", modifiers: [.command, .shift])

            Divider()

            ForEach(FlowTheme.all) { theme in
                Button(theme.name) {
                    preferences.themeID = theme.id
                }
            }
        }
    }
}
