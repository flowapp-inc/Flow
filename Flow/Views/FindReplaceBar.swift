import SwiftUI

struct FindReplaceBar: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences
    @FocusState private var focused: Bool

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(nsColor: theme.mutedText))

            TextField("Find", text: $model.findQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($focused)
                .padding(.horizontal, 8)
                .frame(width: 220, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: theme.editorSurface)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: theme.gutterText.withAlpha(0.25))))
                .onChange(of: model.findQuery) { _, _ in
                    model.currentFindIndex = 0
                    updateRangesRespectingFileSize()
                }

            Text("\(model.findMatchCount)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(nsColor: theme.mutedText))
                .frame(width: 34, alignment: .leading)

            Button {
                model.findPrevious()
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .help("Previous")

            Button {
                model.findNext()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .help("Next")

            Toggle("Aa", isOn: $model.findCaseSensitive)
                .toggleStyle(.button)
                .font(.system(size: 11, weight: .semibold))
                .onChange(of: model.findCaseSensitive) { _, _ in updateRangesRespectingFileSize() }
                .help("Case Sensitive")

            Toggle(".*", isOn: $model.findRegex)
                .toggleStyle(.button)
                .font(.system(size: 11, weight: .semibold))
                .disabled(model.selectedDocument?.shouldDisableLiveRegexSearch == true)
                .onChange(of: model.findRegex) { _, _ in updateRangesRespectingFileSize() }
                .help("Regex")

            Divider()
                .frame(height: 20)

            TextField("Replace", text: $model.replaceQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .frame(width: 200, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: theme.editorSurface)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: theme.gutterText.withAlpha(0.25))))

            Button("Replace") {
                model.replaceCurrent()
            }
            .controlSize(.small)

            Button("All") {
                model.replaceAll()
            }
            .controlSize(.small)

            Spacer()

            Button {
                model.findPanelVisible = false
                if model.documentSearchVisible {
                    model.performDocumentSearch()
                } else {
                    model.selectedDocument?.findRanges = []
                    model.selectedDocument?.selectedFindRange = nil
                }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help("Close Find")
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Color(nsColor: theme.background))
        .onAppear {
            focused = true
            if model.selectedDocument?.shouldDisableLiveRegexSearch == true {
                model.findRegex = false
            }
            model.updateFindRanges()
        }
    }

    private func updateRangesRespectingFileSize() {
        if model.selectedDocument?.largeFileModeEnabled == true {
            model.scheduleFindRangeUpdate()
        } else {
            model.updateFindRanges()
        }
    }
}
