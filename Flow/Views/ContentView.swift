import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: EditorPreferences

    private let sidebarWidth: CGFloat = 300
    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        VStack(spacing: 0) {
            FlowTitlebarView()

            ZStack(alignment: .leading) {
                editorSurface
                    .padding(.leading, preferences.sidebarVisible ? sidebarWidth : 0)

                if preferences.sidebarVisible {
                    FileBrowserView()
                        .frame(width: sidebarWidth)
                        .zIndex(1)
                }
            }
            .background(Color(nsColor: theme.background))
        }
        .overlay {
            overlayLayer
        }
        .frame(minWidth: 920, minHeight: 580)
        .background(theme.swiftBackground)
        .preferredColorScheme(theme.colorScheme)
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowAppearanceAccessor(theme: theme, followsTheme: preferences.titlebarFollowsTheme))
        .onReceive(NotificationCenter.default.publisher(for: .flowOpenFiles)) { notification in
            if let urls = notification.object as? [URL] {
                model.openURLs(urls)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private var editorSurface: some View {
        VStack(spacing: 0) {
            TabBarView()

            if model.findPanelVisible {
                FindReplaceBar()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            EditorWorkspaceView()

            StatusBarView()
        }
        .background(Color(nsColor: theme.background))
    }

    private var overlayLayer: some View {
        ZStack(alignment: .topTrailing) {
            if model.quickOpenVisible {
                Color.black.opacity(theme.isDark ? 0.22 : 0.10)
                    .ignoresSafeArea()
                    .onTapGesture {
                        model.quickOpenVisible = false
                    }
                QuickOpenView()
                    .environmentObject(model)
                    .environmentObject(preferences)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
            }

            if model.goToLineVisible {
                Color.black.opacity(theme.isDark ? 0.18 : 0.08)
                    .ignoresSafeArea()
                    .onTapGesture {
                        model.goToLineVisible = false
                    }
                GoToLineOverlay()
                    .environmentObject(model)
                    .environmentObject(preferences)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
            }

            if model.commandPaletteVisible {
                Color.black.opacity(theme.isDark ? 0.20 : 0.08)
                    .ignoresSafeArea()
                    .onTapGesture {
                        model.closeCommandPalette()
                    }

                CommandPaletteView()
                    .environmentObject(model)
                    .environmentObject(preferences)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
            }

            if model.documentSearchVisible {
                DocumentSearchOverlay()
                    .environmentObject(model)
                    .environmentObject(preferences)
                    .padding(.top, 48)
                    .padding(.trailing, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.14), value: model.quickOpenVisible)
        .animation(.easeOut(duration: 0.14), value: model.commandPaletteVisible)
        .animation(.easeOut(duration: 0.14), value: model.documentSearchVisible)
        .animation(.easeOut(duration: 0.14), value: model.goToLineVisible)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }

                if let url {
                    DispatchQueue.main.async {
                        model.openURLs([url])
                    }
                }
            }
        }
        return true
    }
}
