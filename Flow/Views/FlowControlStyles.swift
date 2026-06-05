import SwiftUI

struct FlowIconButtonStyle: ButtonStyle {
    let theme: FlowTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(nsColor: theme.mutedText))
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: configuration.isPressed ? theme.selection : theme.editorSurface.withAlpha(0.001)))
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}
