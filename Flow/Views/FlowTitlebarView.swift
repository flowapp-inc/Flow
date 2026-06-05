import SwiftUI

struct FlowTitlebarView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        HStack(spacing: 14) {
            WindowDragHandleView()
                .frame(width: 118, height: 38)

            controlCluster {
                titlebarButton("sidebar.left", help: "Toggle Sidebar") {
                    preferences.sidebarVisible.toggle()
                }
                titlebarButton("doc.badge.plus", help: "New File") {
                    model.newDocument()
                }
                titlebarButton("folder", help: "Open") {
                    model.openPanel()
                }
                titlebarButton("square.and.arrow.down", help: "Save") {
                    model.saveSelected()
                }
            }

            Menu {
                ForEach(FlowTheme.all) { item in
                    Button {
                        preferences.themeID = item.id
                    } label: {
                        if item.id == preferences.themeID {
                            Label(item.name, systemImage: "checkmark")
                        } else {
                            Text(item.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paintpalette")
                    Text(theme.name)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(nsColor: theme.text))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(capsuleBackground)
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            .help("Theme")

            Menu {
                Button("Vertical Split") {
                    model.toggleSplit(.vertical)
                }
                Button("Horizontal Split") {
                    model.toggleSplit(.horizontal)
                }
                Divider()
                Button("Close Split") {
                    model.toggleSplit(.none)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: splitIconName)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(nsColor: theme.text))
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background(capsuleBackground)
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            .help("Split Editor")

            WindowDragHandleView()
                .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38)
        }
        .frame(height: 38)
        .background(Color(nsColor: theme.background))
        .contentShape(Rectangle())
    }

    private var splitIconName: String {
        switch model.splitLayout {
        case .horizontal: "rectangle.split.2x1"
        case .vertical: "rectangle.split.1x2"
        case .none: "rectangle.split.2x1.fill"
        }
    }

    private var capsuleBackground: some View {
        Capsule()
            .fill(Color(nsColor: theme.editorSurface.withAlpha(theme.isDark ? 0.68 : 0.85)))
    }

    private func controlCluster<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 2) {
            content()
        }
        .padding(.horizontal, 6)
        .frame(height: 28)
        .background(capsuleBackground)
    }

    private func titlebarButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .buttonStyle(FlowTitlebarButtonStyle(theme: theme))
        .help(help)
    }
}

private struct FlowTitlebarButtonStyle: ButtonStyle {
    let theme: FlowTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(nsColor: theme.text))
            .frame(width: 28, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: configuration.isPressed ? theme.selection : theme.editorSurface.withAlpha(0.001)))
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}
