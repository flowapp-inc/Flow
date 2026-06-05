import AppKit
import SwiftUI
@preconcurrency import Highlightr

struct CodeEditorView: NSViewRepresentable {
    @ObservedObject var document: EditorDocument
    @ObservedObject var preferences: EditorPreferences

    let theme: FlowTheme
    let onTextChanged: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> EditorContainerView {
        let container = EditorContainerView()
        container.textView.delegate = context.coordinator
        container.onVisibleRangeChanged = {
            context.coordinator.scheduleVisibleHighlight()
        }
        context.coordinator.container = container
        context.coordinator.installInitialText(in: container)
        return container
    }

    func updateNSView(_ nsView: EditorContainerView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.container = nsView
        nsView.onVisibleRangeChanged = {
            context.coordinator.scheduleVisibleHighlight()
        }
        nsView.apply(document: document, preferences: preferences, theme: theme)
        context.coordinator.synchronizeTextIfNeeded(in: nsView)
        context.coordinator.applySelectionRequestIfNeeded(in: nsView)
        context.coordinator.highlightAfterViewUpdate(in: nsView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        enum HighlightReason {
            case update
            case edit
            case immediate
        }

        var parent: CodeEditorView
        weak var container: EditorContainerView?

        private let highlightr = Highlightr()
        private var currentHighlightrTheme: String?
        private var isApplyingTextFromModel = false
        private var lastSelectionRequestID: UUID?
        private var lastHighlightSignature = ""
        private var scheduledHighlight: DispatchWorkItem?
        private var needsInitialHighlight = true
        private var lastLanguage: String?
        private var isPerformingProgrammaticInsertion = false
        private var lastEditTime = Date.distantPast

        init(parent: CodeEditorView) {
            self.parent = parent
            super.init()
        }

        func installInitialText(in container: EditorContainerView) {
            let attributes = container.baseAttributes(font: parent.preferences.editorFont, theme: parent.theme)
            container.textView.textStorage?.setAttributedString(NSAttributedString(string: parent.document.text, attributes: attributes))
            lastHighlightSignature = ""
            needsInitialHighlight = true
        }

        func synchronizeTextIfNeeded(in container: EditorContainerView) {
            guard container.textView.string != parent.document.text else { return }
            isApplyingTextFromModel = true
            let selected = container.textView.selectedRange()
            let attributes = container.baseAttributes(font: parent.preferences.editorFont, theme: parent.theme)
            container.textView.textStorage?.setAttributedString(NSAttributedString(string: parent.document.text, attributes: attributes))
            let length = (parent.document.text as NSString).length
            container.textView.setSelectedRange(NSRange(location: min(selected.location, length), length: min(selected.length, max(0, length - selected.location))))
            isApplyingTextFromModel = false
            lastHighlightSignature = ""
            needsInitialHighlight = true
        }

        func scheduleVisibleHighlight() {
            guard parent.document.shouldUseViewportHighlighting else { return }
            scheduledHighlight?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self, let container = self.container else { return }
                self.highlight(in: container, reason: .update)
            }
            scheduledHighlight = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
        }

        func applySelectionRequestIfNeeded(in container: EditorContainerView) {
            guard lastSelectionRequestID != parent.document.selectionRequestID else { return }
            lastSelectionRequestID = parent.document.selectionRequestID
            let length = (container.textView.string as NSString).length
            let range = parent.document.selectionRange
            guard range.location != NSNotFound, range.location + range.length <= length else { return }
            container.textView.setSelectedRange(range)
            container.textView.scrollRangeToVisible(range)
            container.textView.window?.makeFirstResponder(container.textView)
            container.textView.needsDisplay = true
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingTextFromModel,
                  let textView = notification.object as? NSTextView else {
                return
            }
            parent.document.replaceText(textView.string)
            parent.onTextChanged()
            if parent.document.shouldShowDetailedMinimap {
                container?.minimapView.text = textView.string
            }
            container?.lineNumberRuler.needsDisplay = true
            if let container {
                lastEditTime = Date()
                scheduleEditHighlight(in: container)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.document.selectionRange = textView.selectedRange()
            textView.needsDisplay = true
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard !isPerformingProgrammaticInsertion else { return true }
            guard let replacementString else { return true }

            if replacementString == "\n" || replacementString == "\r" {
                let insertion = FormatterService.indentationAfterNewline(
                    in: textView.string,
                    location: affectedCharRange.location,
                    language: parent.document.effectiveLanguage
                )
                performProgrammaticInsertion(insertion, in: textView, replacementRange: affectedCharRange)
                return false
            }

            let pairs: [String: String] = ["(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'"]
            guard let closing = pairs[replacementString] else { return true }

            let nsText = textView.string as NSString
            let selected = affectedCharRange.length > 0 ? nsText.substring(with: affectedCharRange) : ""
            let insertion = replacementString + selected + closing
            performProgrammaticInsertion(insertion, in: textView, replacementRange: affectedCharRange)
            textView.setSelectedRange(NSRange(location: affectedCharRange.location + 1, length: selected.isEmpty ? 0 : (selected as NSString).length))
            return false
        }

        private func performProgrammaticInsertion(_ insertion: String, in textView: NSTextView, replacementRange: NSRange) {
            isPerformingProgrammaticInsertion = true
            defer { isPerformingProgrammaticInsertion = false }
            textView.insertText(insertion, replacementRange: replacementRange)
        }

        func highlight(in container: EditorContainerView, reason: HighlightReason) {
            guard let textStorage = container.textView.textStorage else { return }

            configureHighlightrIfNeeded()

            let text = container.textView.string
            let language = parent.document.effectiveLanguage
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            guard fullRange.length > 0 else { return }

            let targetRange = rangeToHighlight(in: container, textLength: fullRange.length, reason: reason)
            guard targetRange.length > 0 else { return }
            let signature = [
                parent.theme.id,
                language ?? "auto",
                "\(parent.preferences.fontSize)",
                "\(parent.document.languageRevision)",
                "\(fullRange.length)",
                "\(targetRange.location)",
                "\(targetRange.length)",
                "\(parent.document.findRevision)",
                "\(parent.document.selectedFindRange?.location ?? -1)"
            ].joined(separator: "|")

            if reason == .update, signature == lastHighlightSignature {
                return
            }
            lastHighlightSignature = signature

            let base = container.baseAttributes(font: parent.preferences.editorFont, theme: parent.theme)
            textStorage.beginEditing()
            let resetRange = parent.document.shouldUseViewportHighlighting ? targetRange : fullRange
            textStorage.addAttributes(base, range: resetRange)

            let fragment = (text as NSString).substring(with: targetRange)
            if shouldUseHighlightr(for: targetRange, textLength: fullRange.length, language: language),
               let highlighted = highlightr?.highlight(fragment, as: language, fastRender: true),
               highlighted.length == targetRange.length {
                highlighted.enumerateAttributes(in: NSRange(location: 0, length: highlighted.length), options: []) { attributes, range, _ in
                    var merged = base
                    attributes.forEach { key, value in
                        if key != .backgroundColor {
                            merged[key] = value
                        }
                    }
                    merged[.font] = parent.preferences.editorFont
                    textStorage.setAttributes(merged, range: NSRange(location: targetRange.location + range.location, length: range.length))
                }
            }

            SyntaxRegexHighlighter.apply(
                to: textStorage,
                text: text,
                range: targetRange,
                language: language,
                theme: parent.theme
            )
            applyFindHighlights(to: textStorage)
            textStorage.endEditing()
            container.textView.typingAttributes = base
            container.textView.needsDisplay = true
            container.lineNumberRuler.needsDisplay = true
        }

        func highlightAfterViewUpdate(in container: EditorContainerView) {
            parent.document.updateResolvedSyntaxLanguage()
            let language = parent.document.effectiveLanguage
            if language != lastLanguage {
                lastHighlightSignature = ""
                needsInitialHighlight = true
                lastLanguage = language
            }

            if Date().timeIntervalSince(lastEditTime) < 0.08 {
                scheduleEditHighlight(in: container)
                return
            }

            let reason: HighlightReason = needsInitialHighlight ? .immediate : .update
            let wasInitial = needsInitialHighlight
            needsInitialHighlight = false
            highlight(in: container, reason: reason)

            if wasInitial {
                scheduledHighlight?.cancel()
                let item = DispatchWorkItem { [weak self, weak container] in
                    guard let self, let container else { return }
                    self.lastHighlightSignature = ""
                    self.highlight(in: container, reason: .immediate)
                }
                scheduledHighlight = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: item)
            }
        }

        private func scheduleEditHighlight(in container: EditorContainerView) {
            scheduledHighlight?.cancel()
            let delay: TimeInterval = parent.document.shouldUseViewportHighlighting ? 0.09 : 0.035
            let item = DispatchWorkItem { [weak self, weak container] in
                guard let self, let container else { return }
                self.highlight(in: container, reason: .edit)
            }
            scheduledHighlight = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }

        private func configureHighlightrIfNeeded() {
            guard currentHighlightrTheme != parent.theme.highlightrTheme else { return }
            if highlightr?.setTheme(to: parent.theme.highlightrTheme) == false {
                _ = highlightr?.setTheme(to: parent.theme.isDark ? "atom-one-dark" : "github")
            }
            currentHighlightrTheme = parent.theme.highlightrTheme
        }

        private func rangeToHighlight(in container: EditorContainerView, textLength: Int, reason: HighlightReason) -> NSRange {
            guard parent.document.shouldUseViewportHighlighting else {
                return NSRange(location: 0, length: textLength)
            }

            guard let layoutManager = container.textView.layoutManager,
                  let textContainer = container.textView.textContainer else {
                return NSRange(location: 0, length: min(textLength, 60_000))
            }

            let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: container.scrollView.contentView.bounds, in: textContainer)
            var charRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
            let nsText = container.textView.string as NSString
            charRange = nsText.paragraphRange(for: charRange)
            if charRange.length == 0 {
                return NSRange(location: 0, length: min(textLength, 60_000))
            }
            let paddedLocation = max(0, charRange.location - 4_000)
            let paddedEnd = min(textLength, NSMaxRange(charRange) + 4_000)
            return NSRange(location: paddedLocation, length: paddedEnd - paddedLocation)
        }

        private func shouldUseHighlightr(for range: NSRange, textLength: Int, language: String?) -> Bool {
            guard language != nil else { return false }
            guard !parent.document.shouldAvoidHighlightr else { return false }
            guard range.length <= 80_000 else { return false }
            if language == "markdown", textLength > 120_000 {
                return false
            }
            return true
        }

        private func applyFindHighlights(to textStorage: NSTextStorage) {
            let length = textStorage.length
            let highlightColor = parent.theme.accent.withAlpha(parent.theme.isDark ? 0.22 : 0.16)
            let selectedColor = parent.theme.accent.withAlpha(parent.theme.isDark ? 0.45 : 0.32)

            for range in parent.document.findRanges where NSMaxRange(range) <= length {
                textStorage.addAttribute(.backgroundColor, value: highlightColor, range: range)
            }

            if let range = parent.document.selectedFindRange, NSMaxRange(range) <= length {
                textStorage.addAttribute(.backgroundColor, value: selectedColor, range: range)
            }
        }
    }
}
