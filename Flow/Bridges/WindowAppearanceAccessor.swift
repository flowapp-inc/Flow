import AppKit
import SwiftUI

struct WindowAppearanceAccessor: NSViewRepresentable {
    let theme: FlowTheme
    let followsTheme: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            applyAppearance(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyAppearance(to: nsView.window)
        }
    }

    private func applyAppearance(to window: NSWindow?) {
        guard let window else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
        window.setContentBorderThickness(0, for: .minY)
        window.setContentBorderThickness(0, for: .maxY)
        window.toolbar = nil
        window.backgroundColor = theme.background
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = theme.background.cgColor
        window.isMovableByWindowBackground = false
        window.appearance = followsTheme ? NSAppearance(named: theme.isDark ? .darkAqua : .aqua) : nil
    }
}
