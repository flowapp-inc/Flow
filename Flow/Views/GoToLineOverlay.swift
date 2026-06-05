import SwiftUI

struct GoToLineOverlay: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences
    @FocusState private var focused: Bool

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.to.line.compact")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(nsColor: theme.mutedText))

            TextField("Line", text: $model.goToLineInput)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(nsColor: theme.text))
                .focused($focused)
                .frame(width: 140)
                .onSubmit {
                    model.goToLineFromInput()
                }

            Button {
                model.goToLineFromInput()
            } label: {
                Image(systemName: "return")
            }
            .buttonStyle(GoToLineButtonStyle(theme: theme))
            .help("Go")

            Button {
                model.goToLineVisible = false
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(GoToLineButtonStyle(theme: theme))
            .help("Close")
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(Color(nsColor: theme.background.blended(withFraction: theme.isDark ? 0.10 : 0.04, of: theme.editorSurface) ?? theme.background))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: theme.gutterText.withAlpha(theme.isDark ? 0.20 : 0.16)), lineWidth: 1)
        )
        .shadow(color: .black.opacity(theme.isDark ? 0.26 : 0.10), radius: 22, x: 0, y: 12)
        .onAppear {
            focused = true
        }
    }
}

private struct GoToLineButtonStyle: ButtonStyle {
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
