import SwiftUI

struct DocumentSearchOverlay: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences
    @FocusState private var focused: Bool

    private var theme: FlowTheme { preferences.theme }
    private var document: EditorDocument? { model.selectedDocument }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let warning = model.documentSearchWarning {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.horizontal")
                    Text(warning)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: theme.mutedText))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            Divider()
                .opacity(theme.isDark ? 0.20 : 0.35)

            results
        }
        .frame(width: 420)
        .frame(maxHeight: 410)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: theme.gutterText.withAlpha(theme.isDark ? 0.20 : 0.16)), lineWidth: 1)
        )
        .shadow(color: .black.opacity(theme.isDark ? 0.28 : 0.12), radius: 24, x: 0, y: 14)
        .onAppear {
            focused = true
            if document?.shouldDisableLiveRegexSearch == true {
                model.documentSearchRegex = false
            }
            model.performDocumentSearch()
        }
    }

    private var header: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color(nsColor: theme.mutedText))

                TextField("Search document", text: $model.documentSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(nsColor: theme.text))
                    .focused($focused)
                    .onSubmit {
                        model.nextDocumentSearchResult()
                    }
                    .onChange(of: model.documentSearchQuery) { _, _ in
                        model.documentSearchIndex = 0
                        model.scheduleDocumentSearch()
                    }

                if model.documentSearchIsSearching {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 16, height: 16)
                } else {
                    Text(matchCountText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(nsColor: theme.mutedText))
                        .frame(minWidth: 46, alignment: .trailing)
                }

                Button {
                    model.previousDocumentSearchResult()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(SearchIconButtonStyle(theme: theme))
                .help("Previous Match")

                Button {
                    model.nextDocumentSearchResult()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(SearchIconButtonStyle(theme: theme))
                .help("Next Match")

                Button {
                    model.closeDocumentSearch()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(SearchIconButtonStyle(theme: theme))
                .help("Close")
            }

            HStack(spacing: 7) {
                Toggle("Aa", isOn: $model.documentSearchCaseSensitive)
                    .toggleStyle(SearchToggleStyle(theme: theme))
                    .help("Case Sensitive")
                    .onChange(of: model.documentSearchCaseSensitive) { _, _ in
                        model.documentSearchIndex = 0
                        model.performDocumentSearch()
                    }

                Toggle(".*", isOn: $model.documentSearchRegex)
                    .toggleStyle(SearchToggleStyle(theme: theme))
                    .disabled(document?.shouldDisableLiveRegexSearch == true)
                    .help("Regex")
                    .onChange(of: model.documentSearchRegex) { _, _ in
                        model.documentSearchIndex = 0
                        model.performDocumentSearch()
                    }

                Spacer()

                if document?.largeFileModeEnabled == true {
                    Text("Large File Mode")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(nsColor: theme.accent))
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(
                            Capsule()
                                .fill(Color(nsColor: theme.accent.withAlpha(theme.isDark ? 0.14 : 0.10)))
                        )
                }
            }
        }
        .padding(12)
    }

    private var results: some View {
        Group {
            if model.documentSearchQuery.isEmpty {
                emptyState("Ready")
            } else if model.documentSearchResults.isEmpty && !model.documentSearchIsSearching {
                emptyState("No matches")
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(model.documentSearchResults) { result in
                            DocumentSearchResultRow(
                                result: result,
                                isSelected: selectedResultID == result.id,
                                theme: theme
                            )
                            .onTapGesture {
                                model.selectDocumentSearchResult(result)
                            }
                        }
                    }
                    .padding(7)
                }
            }
        }
        .frame(minHeight: 84, maxHeight: 286)
    }

    private func emptyState(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(nsColor: theme.mutedText))
                .padding(.vertical, 30)
            Spacer()
        }
    }

    private var selectedResultID: Int? {
        guard model.documentSearchResults.indices.contains(model.documentSearchIndex) else { return nil }
        return model.documentSearchResults[model.documentSearchIndex].id
    }

    private var matchCountText: String {
        guard !model.documentSearchResults.isEmpty else { return "0" }
        return "\(model.documentSearchIndex + 1)/\(model.documentSearchResults.count)"
    }

    private var panelBackground: some View {
        Color(nsColor: theme.background.blended(withFraction: theme.isDark ? 0.10 : 0.04, of: theme.editorSurface) ?? theme.background)
    }
}

private struct DocumentSearchResultRow: View {
    let result: DocumentSearchResult
    let isSelected: Bool
    let theme: FlowTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(result.line)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(nsColor: isSelected ? theme.accent : theme.gutterText))
                .frame(width: 42, alignment: .trailing)

            (
                Text(result.prefix)
                    .foregroundColor(Color(nsColor: theme.mutedText))
                + Text(result.match)
                    .foregroundColor(Color(nsColor: theme.text))
                + Text(result.suffix)
                    .foregroundColor(Color(nsColor: theme.mutedText))
            )
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: isSelected ? theme.selection : theme.editorSurface.withAlpha(0.001)))
        )
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct SearchIconButtonStyle: ButtonStyle {
    let theme: FlowTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(nsColor: theme.text))
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: configuration.isPressed ? theme.selection : theme.editorSurface.withAlpha(0.001)))
            )
    }
}

private struct SearchToggleStyle: ToggleStyle {
    let theme: FlowTheme

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(nsColor: configuration.isOn ? theme.background : theme.mutedText))
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(
                    Capsule()
                        .fill(Color(nsColor: configuration.isOn ? theme.accent : theme.editorSurface))
                )
        }
        .buttonStyle(.plain)
    }
}
