import AppKit
import Foundation

final class AppModel: ObservableObject {
    @Published var documents: [EditorDocument] = []
    @Published var selectedDocumentID: UUID? {
        didSet { handleSelectedDocumentChanged(from: oldValue) }
    }
    @Published var secondaryDocumentID: UUID?
    @Published var splitLayout: SplitLayout = .none
    @Published var projectFolder: URL?
    @Published var findPanelVisible = false
    @Published var findQuery = ""
    @Published var replaceQuery = ""
    @Published var findCaseSensitive = false
    @Published var findRegex = false
    @Published var currentFindIndex = 0
    @Published var statusMessage = "Ready"
    @Published var fileBrowserRefreshID = UUID()
    @Published var quickOpenVisible = false
    @Published var quickOpenQuery = ""
    @Published var commandPaletteVisible = false
    @Published var commandPaletteQuery = ""
    @Published var documentSearchVisible = false
    @Published var documentSearchQuery = ""
    @Published var documentSearchResults: [DocumentSearchResult] = []
    @Published var documentSearchIndex = 0
    @Published var documentSearchCaseSensitive = false
    @Published var documentSearchRegex = false
    @Published var documentSearchIsSearching = false
    @Published var documentSearchIsTruncated = false
    @Published var documentSearchWarning: String?
    @Published var goToLineVisible = false
    @Published var goToLineInput = ""

    let preferences: EditorPreferences
    private var scheduledFindUpdate: DispatchWorkItem?
    private var scheduledDocumentSearch: DispatchWorkItem?
    private var documentSearchGeneration = 0

    init(preferences: EditorPreferences) {
        self.preferences = preferences
        restoreOpenTabs()
        if documents.isEmpty {
            newDocument()
        }
    }

    var selectedDocument: EditorDocument? {
        documents.first { $0.id == selectedDocumentID }
    }

    var secondaryDocument: EditorDocument? {
        documents.first { $0.id == secondaryDocumentID } ?? selectedDocument
    }

    var sidebarRoot: URL? {
        projectFolder ?? selectedDocument?.url?.deletingLastPathComponent()
    }

    var findMatchCount: Int {
        selectedDocument?.findRanges.count ?? 0
    }

    var canSearchSelectedDocument: Bool {
        selectedDocument?.kind == .text
    }

    var quickOpenResults: [FileNode] {
        guard let root = sidebarRoot else { return [] }
        let query = quickOpenQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return FileNode.flatFiles(root: root)
            .filter { node in
                guard !query.isEmpty else { return true }
                return node.name.lowercased().contains(query) || node.url.path.lowercased().contains(query)
            }
            .prefix(60)
            .map { $0 }
    }

    func newDocument() {
        let document = EditorDocument()
        documents.append(document)
        selectedDocumentID = document.id
        statusMessage = "New file"
        persistOpenTabs()
    }

    func select(_ document: EditorDocument) {
        selectedDocumentID = document.id
        updateFindRanges()
        scheduleDocumentSearch()
    }

    func reorderTab(draggedID: UUID?, over targetID: UUID) {
        guard let draggedID,
              draggedID != targetID,
              let sourceIndex = documents.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = documents.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        let document = documents.remove(at: sourceIndex)
        let targetIndexAfterRemoval = documents.firstIndex { $0.id == targetID } ?? documents.count
        let insertionIndex = targetIndex > sourceIndex ? targetIndexAfterRemoval + 1 : targetIndexAfterRemoval
        documents.insert(document, at: min(insertionIndex, documents.count))
        statusMessage = "Moved \(document.title)"
    }

    func finishTabReorder() {
        persistOpenTabs()
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else { return }
        openURLs(panel.urls)
    }

    func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.prompt = "Open Folder"

        guard panel.runModal() == .OK, let url = panel.urls.first else { return }
        projectFolder = url
        fileBrowserRefreshID = UUID()
        statusMessage = "Opened \(url.lastPathComponent)"
    }

    func toggleQuickOpen() {
        quickOpenVisible.toggle()
        if quickOpenVisible {
            quickOpenQuery = ""
            commandPaletteVisible = false
        }
    }

    func openFromQuickOpen(_ node: FileNode) {
        openFile(node.url)
        quickOpenVisible = false
        quickOpenQuery = ""
    }

    func showCommandPalette() {
        commandPaletteQuery = ""
        commandPaletteVisible = true
        quickOpenVisible = false
        goToLineVisible = false
        documentSearchVisible = false
    }

    func closeCommandPalette() {
        commandPaletteVisible = false
        commandPaletteQuery = ""
    }

    func openURLs(_ urls: [URL]) {
        for url in urls {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                projectFolder = url
                fileBrowserRefreshID = UUID()
            } else {
                openFile(url)
            }
        }
        persistOpenTabs()
    }

    func openFile(_ url: URL) {
        if let existing = documents.first(where: { $0.url?.standardizedFileURL == url.standardizedFileURL }) {
            selectedDocumentID = existing.id
            statusMessage = "Already open"
            return
        }

        do {
            let document: EditorDocument
            if ImageFileService.isSupportedImage(url) {
                document = EditorDocument(image: try ImageFileService.load(url: url))
            } else {
                let loaded = try FileService.load(url: url)
                document = EditorDocument(
                    url: loaded.url,
                    text: loaded.text,
                    encoding: loaded.encoding,
                    lineEnding: loaded.lineEnding,
                    byteCount: loaded.byteCount
                )
            }
            documents.append(document)
            selectedDocumentID = document.id
            projectFolder = projectFolder ?? url.deletingLastPathComponent()
            preferences.rememberRecentFile(url)
            statusMessage = "Opened \(url.lastPathComponent)"
            if document.largeFileModeEnabled {
                statusMessage = "Opened \(url.lastPathComponent) in Large File Mode"
            }
            scheduleDocumentSearch()
        } catch {
            PromptService.showError(error)
        }
    }

    @discardableResult
    func saveSelected() -> Bool {
        guard let document = selectedDocument else { return false }
        return save(document)
    }

    @discardableResult
    func save(_ document: EditorDocument) -> Bool {
        guard document.kind == .text else {
            statusMessage = "\(document.title) is view-only"
            return true
        }

        guard let url = document.url else {
            return saveAs(document)
        }

        do {
            try FileService.save(text: document.text, to: url, encoding: document.encoding, lineEnding: document.lineEnding)
            document.markSaved(url: url, text: document.text, encoding: document.encoding, lineEnding: document.lineEnding)
            preferences.rememberRecentFile(url)
            persistOpenTabs()
            statusMessage = "Saved \(url.lastPathComponent)"
            return true
        } catch {
            PromptService.showError(error)
            return false
        }
    }

    @discardableResult
    func saveAsSelected() -> Bool {
        guard let document = selectedDocument else { return false }
        return saveAs(document)
    }

    func saveAll() {
        for document in documents where document.isDirty {
            _ = save(document)
        }
        statusMessage = "Saved all"
    }

    @discardableResult
    func saveAs(_ document: EditorDocument) -> Bool {
        guard document.kind == .text else {
            statusMessage = "\(document.title) is view-only"
            return true
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = document.url?.lastPathComponent ?? "Untitled.txt"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        do {
            try FileService.save(text: document.text, to: url, encoding: document.encoding, lineEnding: document.lineEnding)
            document.markSaved(url: url, text: document.text, encoding: document.encoding, lineEnding: document.lineEnding)
            projectFolder = projectFolder ?? url.deletingLastPathComponent()
            preferences.rememberRecentFile(url)
            persistOpenTabs()
            fileBrowserRefreshID = UUID()
            statusMessage = "Saved \(url.lastPathComponent)"
            return true
        } catch {
            PromptService.showError(error)
            return false
        }
    }

    func closeSelectedTab() {
        guard let document = selectedDocument else { return }
        close(document)
    }

    func close(_ document: EditorDocument) {
        guard confirmClose(document) else { return }
        documents.removeAll { $0.id == document.id }

        if selectedDocumentID == document.id {
            selectedDocumentID = documents.last?.id
        }

        if secondaryDocumentID == document.id {
            secondaryDocumentID = documents.first(where: { $0.id != selectedDocumentID })?.id ?? selectedDocumentID
        }

        if documents.isEmpty {
            splitLayout = .none
            secondaryDocumentID = nil
        }

        persistOpenTabs()
        statusMessage = "Closed \(document.title)"
    }

    func toggleSplit(_ layout: SplitLayout) {
        guard layout != .none else {
            splitLayout = .none
            return
        }

        if splitLayout == layout {
            splitLayout = .none
            secondaryDocumentID = nil
        } else {
            splitLayout = layout
            if secondaryDocumentID == nil {
                secondaryDocumentID = documents.first(where: { $0.id != selectedDocumentID })?.id ?? selectedDocumentID
            }
        }
    }

    func formatSelectedDocument() {
        guard let document = selectedDocument, document.kind == .text else {
            statusMessage = "Images cannot be formatted"
            return
        }
        document.updateResolvedSyntaxLanguage()
        let language = document.effectiveLanguage ?? LanguageDetector.detectLanguage(for: document.url, contents: document.text)
        let formatted = FormatterService.format(document.text, language: language)
        document.replaceText(formatted)
        updateFindRanges()
        scheduleDocumentSearch()
        statusMessage = "Formatted \(document.title) as \(document.displayLanguage)"
    }

    func toggleCommentSelectedDocument() {
        guard let document = selectedDocument, document.kind == .text,
              let result = TextEditingService.toggleLineComment(
                text: document.text,
                selection: document.selectionRange,
                language: document.effectiveLanguage
              ) else {
            statusMessage = "No line comment for this language"
            return
        }

        document.replaceText(result.text)
        document.requestSelection(result.selection)
        updateFindRanges()
        scheduleDocumentSearch()
        statusMessage = "Toggled comment"
    }

    func duplicateLineOrSelection() {
        guard let document = selectedDocument, document.kind == .text else { return }
        let result = TextEditingService.duplicateLineOrSelection(text: document.text, selection: document.selectionRange)
        document.replaceText(result.text)
        document.requestSelection(result.selection)
        updateFindRanges()
        scheduleDocumentSearch()
        statusMessage = "Duplicated"
    }

    func trimTrailingWhitespace() {
        guard let document = selectedDocument, document.kind == .text else { return }
        let trimmed = TextEditingService.trimTrailingWhitespace(text: document.text)
        document.replaceText(trimmed)
        scheduleDocumentSearch()
        statusMessage = "Trimmed trailing whitespace"
    }

    func reloadSelectedFromDisk() {
        guard let document = selectedDocument, let url = document.url else { return }
        if document.isDirty, !PromptService.confirmDiscardChanges(title: document.title) {
            return
        }

        do {
            if ImageFileService.isSupportedImage(url) {
                let loaded = try ImageFileService.load(url: url)
                document.kind = .image
                document.text = ""
                document.imageData = loaded.data
                document.imagePixelSize = loaded.pixelSize
                document.imageFormat = loaded.format
                document.byteCount = loaded.byteCount
                document.isDirty = false
                document.detectedLanguage = "image"
                document.languageOverride = nil
                document.updateResolvedSyntaxLanguage()
            } else {
                let loaded = try FileService.load(url: url)
                document.kind = .text
                document.imageData = nil
                document.imagePixelSize = nil
                document.imageFormat = nil
                document.markSaved(
                    url: loaded.url,
                    text: loaded.text,
                    encoding: loaded.encoding,
                    lineEnding: loaded.lineEnding
                )
            }
            updateFindRanges()
            scheduleDocumentSearch()
            statusMessage = "Reloaded \(document.title)"
        } catch {
            PromptService.showError(error)
        }
    }

    func copySelectedPath() {
        guard let url = selectedDocument?.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
        statusMessage = "Copied path"
    }

    func revealSelectedInFinder() {
        guard let url = selectedDocument?.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        statusMessage = "Revealed \(url.lastPathComponent)"
    }

    func toggleFindPanel() {
        findPanelVisible.toggle()
        if findPanelVisible {
            updateFindRanges()
        }
    }

    func updateFindRanges() {
        guard let document = selectedDocument, document.kind == .text, !findQuery.isEmpty else {
            selectedDocument?.findRanges = []
            selectedDocument?.selectedFindRange = nil
            currentFindIndex = 0
            return
        }
        guard !(document.shouldDisableLiveRegexSearch && findRegex) else {
            document.findRanges = []
            document.selectedFindRange = nil
            currentFindIndex = 0
            statusMessage = "Regex search disabled in Large File Mode"
            return
        }

        let response = DocumentSearchService.ranges(
            query: findQuery,
            in: document.text,
            options: DocumentSearchOptions(
                caseSensitive: findCaseSensitive,
                regex: findRegex,
                allowRegexInLargeFile: false,
                maxResults: document.maxFindHighlights
            ),
            largeFileMode: document.largeFileModeEnabled
        )
        let ranges = response.ranges
        document.findRanges = ranges
        currentFindIndex = min(currentFindIndex, max(ranges.count - 1, 0))
        document.selectedFindRange = ranges.indices.contains(currentFindIndex) ? ranges[currentFindIndex] : nil
        if response.isTruncated {
            statusMessage = "Showing first \(ranges.count) matches"
        } else if let error = response.errorMessage {
            statusMessage = error
        }
    }

    func scheduleFindRangeUpdate() {
        scheduledFindUpdate?.cancel()
        guard findPanelVisible, !findQuery.isEmpty else { return }

        let item = DispatchWorkItem { [weak self] in
            self?.updateFindRanges()
        }
        scheduledFindUpdate = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: item)
    }

    func findNext() {
        guard let document = selectedDocument, document.kind == .text else { return }
        updateFindRanges()
        guard !document.findRanges.isEmpty else { return }
        currentFindIndex = (currentFindIndex + 1) % document.findRanges.count
        selectCurrentFindRange()
    }

    func findPrevious() {
        guard let document = selectedDocument, document.kind == .text else { return }
        updateFindRanges()
        guard !document.findRanges.isEmpty else { return }
        currentFindIndex = (currentFindIndex - 1 + document.findRanges.count) % document.findRanges.count
        selectCurrentFindRange()
    }

    func replaceCurrent() {
        guard let document = selectedDocument,
              document.kind == .text,
              let range = document.selectedFindRange,
              range.location != NSNotFound else {
            return
        }

        let nsText = document.text as NSString
        let replacement = replacementString(for: range, in: document.text)
        let newText = nsText.replacingCharacters(in: range, with: replacement)
        document.replaceText(newText)
        updateFindRanges()
        scheduleDocumentSearch()
        selectCurrentFindRange()
        statusMessage = "Replaced"
    }

    func replaceAll() {
        guard let document = selectedDocument, document.kind == .text, !findQuery.isEmpty else { return }

        let original = document.text
        let newText: String

        if findRegex, let regex = try? regularExpression() {
            let range = original.nsRange
            newText = regex.stringByReplacingMatches(in: original, range: range, withTemplate: replaceQuery)
        } else {
            let options: NSString.CompareOptions = findCaseSensitive ? [] : [.caseInsensitive]
            newText = original.replacingOccurrences(of: findQuery, with: replaceQuery, options: options)
        }

        document.replaceText(newText)
        updateFindRanges()
        scheduleDocumentSearch()
        statusMessage = "Replaced all"
    }

    func showDocumentSearch() {
        guard canSearchSelectedDocument else {
            statusMessage = "Images cannot be searched"
            return
        }
        documentSearchVisible = true
        commandPaletteVisible = false
        documentSearchQuery = documentSearchQuery.isEmpty ? findQuery : documentSearchQuery
        performDocumentSearch()
    }

    func closeDocumentSearch() {
        documentSearchVisible = false
        scheduledDocumentSearch?.cancel()
        documentSearchGeneration += 1
        documentSearchIsSearching = false
        documentSearchWarning = nil
        if !findPanelVisible {
            selectedDocument?.findRanges = []
            selectedDocument?.selectedFindRange = nil
        }
    }

    func scheduleDocumentSearch() {
        scheduledDocumentSearch?.cancel()
        guard documentSearchVisible else { return }

        let item = DispatchWorkItem { [weak self] in
            self?.performDocumentSearch()
        }
        scheduledDocumentSearch = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14, execute: item)
    }

    func performDocumentSearch() {
        scheduledDocumentSearch?.cancel()
        documentSearchGeneration += 1
        guard let document = selectedDocument, document.kind == .text else {
            documentSearchResults = []
            documentSearchWarning = nil
            documentSearchIsSearching = false
            return
        }

        let query = documentSearchQuery.trimmingCharacters(in: .newlines)
        guard !query.isEmpty else {
            documentSearchResults = []
            document.findRanges = []
            document.selectedFindRange = nil
            documentSearchWarning = document.largeFileModeEnabled ? "Large File Mode: type to search capped results" : nil
            documentSearchIsSearching = false
            return
        }

        let generation = documentSearchGeneration
        let text = document.text
        let largeFileMode = document.largeFileModeEnabled
        let maxResults = document.maxFindHighlights
        let options = DocumentSearchOptions(
            caseSensitive: documentSearchCaseSensitive,
            regex: documentSearchRegex,
            allowRegexInLargeFile: false,
            maxResults: maxResults
        )

        documentSearchIsSearching = true
        documentSearchWarning = largeFileMode ? "Large File Mode: capped to \(maxResults) matches" : nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let response = DocumentSearchService.search(
                query: query,
                in: text,
                options: options,
                largeFileMode: largeFileMode
            )

            DispatchQueue.main.async {
                guard let self, generation == self.documentSearchGeneration else { return }
                guard let currentDocument = self.selectedDocument, currentDocument.id == document.id else { return }

                self.documentSearchIsSearching = false
                self.documentSearchResults = response.results
                self.documentSearchIsTruncated = response.isTruncated
                self.documentSearchIndex = min(self.documentSearchIndex, max(response.results.count - 1, 0))
                currentDocument.findRanges = response.ranges
                currentDocument.selectedFindRange = response.results.indices.contains(self.documentSearchIndex)
                    ? response.results[self.documentSearchIndex].range
                    : nil

                if response.skippedRegexForLargeFile {
                    self.documentSearchWarning = "Regex is disabled in Large File Mode"
                } else if let error = response.errorMessage {
                    self.documentSearchWarning = error
                } else if response.isTruncated {
                    self.documentSearchWarning = "Showing first \(response.results.count) matches"
                } else if largeFileMode {
                    self.documentSearchWarning = "Large File Mode: expensive features are paused"
                } else {
                    self.documentSearchWarning = nil
                }
            }
        }
    }

    func selectDocumentSearchResult(_ result: DocumentSearchResult) {
        guard let index = documentSearchResults.firstIndex(where: { $0.id == result.id }) else { return }
        documentSearchIndex = index
        selectedDocument?.selectedFindRange = result.range
        selectedDocument?.requestSelection(result.range)
        statusMessage = "Match \(index + 1) of \(documentSearchResults.count)"
    }

    func nextDocumentSearchResult() {
        guard !documentSearchResults.isEmpty else { return }
        documentSearchIndex = (documentSearchIndex + 1) % documentSearchResults.count
        selectDocumentSearchResult(documentSearchResults[documentSearchIndex])
    }

    func previousDocumentSearchResult() {
        guard !documentSearchResults.isEmpty else { return }
        documentSearchIndex = (documentSearchIndex - 1 + documentSearchResults.count) % documentSearchResults.count
        selectDocumentSearchResult(documentSearchResults[documentSearchIndex])
    }

    func showGoToLine() {
        guard selectedDocument?.kind == .text else {
            statusMessage = "Images do not have line numbers"
            return
        }
        goToLineInput = ""
        goToLineVisible = true
        commandPaletteVisible = false
    }

    func goToLineFromInput() {
        guard let document = selectedDocument,
              let target = TextLocationService.parseLineColumn(goToLineInput),
              let range = TextLocationService.rangeForLine(target.line, column: target.column, in: document.text) else {
            statusMessage = "Invalid line"
            return
        }

        document.requestSelection(range)
        documentSearchVisible = false
        goToLineVisible = false
        statusMessage = "Jumped to line \(target.line)"
    }

    func setProjectFolder(_ url: URL?) {
        projectFolder = url
        fileBrowserRefreshID = UUID()
    }

    func createFile(in folder: URL?) {
        let targetFolder = folder ?? sidebarRoot
        guard let targetFolder else { return }
        guard let name = PromptService.askForName(title: "New File", message: "Name this file.") else { return }

        let url = targetFolder.appendingPathComponent(name)
        do {
            try Data().write(to: url, options: .withoutOverwriting)
            fileBrowserRefreshID = UUID()
            openFile(url)
        } catch {
            PromptService.showError(error)
        }
    }

    func createFolder(in folder: URL?) {
        let targetFolder = folder ?? sidebarRoot
        guard let targetFolder else { return }
        guard let name = PromptService.askForName(title: "New Folder", message: "Name this folder.") else { return }

        do {
            try FileManager.default.createDirectory(at: targetFolder.appendingPathComponent(name), withIntermediateDirectories: false)
            fileBrowserRefreshID = UUID()
        } catch {
            PromptService.showError(error)
        }
    }

    func renameItem(_ url: URL) {
        guard let name = PromptService.askForName(title: "Rename", message: "Choose a new name.", defaultValue: url.lastPathComponent) else { return }
        let destination = url.deletingLastPathComponent().appendingPathComponent(name)

        do {
            try FileManager.default.moveItem(at: url, to: destination)
            for document in documents where document.url?.standardizedFileURL == url.standardizedFileURL {
                document.url = destination
                if document.kind == .text {
                    document.detectedLanguage = LanguageDetector.detectLanguage(for: destination, contents: document.text)
                }
            }
            fileBrowserRefreshID = UUID()
            persistOpenTabs()
        } catch {
            PromptService.showError(error)
        }
    }

    func deleteItem(_ url: URL) {
        guard PromptService.confirmDelete(url: url) else { return }
        do {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
            documents.removeAll { document in
                guard let documentURL = document.url else { return false }
                return documentURL.standardizedFileURL.path.hasPrefix(url.standardizedFileURL.path)
            }
            selectedDocumentID = documents.last?.id
            fileBrowserRefreshID = UUID()
            persistOpenTabs()
        } catch {
            PromptService.showError(error)
        }
    }

    private func confirmClose(_ document: EditorDocument) -> Bool {
        guard document.isDirty else { return true }

        let alert = NSAlert()
        alert.messageText = "Save changes to \(document.title)?"
        alert.informativeText = "Your changes will be lost if you close this tab without saving."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don't Save")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return save(document)
        case .alertSecondButtonReturn:
            return false
        default:
            return true
        }
    }

    private func restoreOpenTabs() {
        let urls = preferences.openBookmarks.compactMap(BookmarkStore.resolve)
        for url in urls {
            do {
                if ImageFileService.isSupportedImage(url) {
                    documents.append(EditorDocument(image: try ImageFileService.load(url: url)))
                } else {
                    let loaded = try FileService.load(url: url)
                    documents.append(EditorDocument(
                        url: loaded.url,
                        text: loaded.text,
                        encoding: loaded.encoding,
                        lineEnding: loaded.lineEnding,
                        byteCount: loaded.byteCount
                    ))
                }
            } catch {
                continue
            }
        }
        selectedDocumentID = documents.first?.id
        projectFolder = documents.first?.url?.deletingLastPathComponent()
    }

    private func persistOpenTabs() {
        preferences.rememberOpenFiles(documents.compactMap(\.url))
    }

    private func handleSelectedDocumentChanged(from previousID: UUID?) {
        guard previousID != selectedDocumentID else { return }
        currentFindIndex = 0
        documentSearchIndex = 0

        if findPanelVisible {
            updateFindRanges()
        }

        if documentSearchVisible {
            if selectedDocument?.kind == .text {
                scheduleDocumentSearch()
            } else {
                closeDocumentSearch()
            }
        }
    }

    private func selectCurrentFindRange() {
        guard let document = selectedDocument, document.findRanges.indices.contains(currentFindIndex) else { return }
        let range = document.findRanges[currentFindIndex]
        document.selectedFindRange = range
        document.requestSelection(range)
    }

    private func regularExpression() throws -> NSRegularExpression {
        let options: NSRegularExpression.Options = findCaseSensitive ? [] : [.caseInsensitive]
        return try NSRegularExpression(pattern: findQuery, options: options)
    }

    private func replacementString(for range: NSRange, in text: String) -> String {
        guard findRegex, let regex = try? regularExpression() else { return replaceQuery }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: range) else { return replaceQuery }
        return regex.replacementString(
            for: match,
            in: text,
            offset: 0,
            template: replaceQuery
        ).isEmpty && nsText.substring(with: range).isEmpty ? replaceQuery : regex.replacementString(
            for: match,
            in: text,
            offset: 0,
            template: replaceQuery
        )
    }
}
