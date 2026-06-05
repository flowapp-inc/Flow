import AppKit

enum PromptService {
    static func askForName(title: String, message: String, defaultValue: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = defaultValue
        alert.accessoryView = field

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    static func showError(_ error: Error) {
        NSAlert(error: error).runModal()
    }

    static func confirmDelete(url: URL) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Delete \(url.lastPathComponent)?"
        alert.informativeText = "The item will be moved to the Trash."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func confirmDiscardChanges(title: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Reload \(title)?"
        alert.informativeText = "Unsaved changes in this tab will be replaced with the file on disk."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
