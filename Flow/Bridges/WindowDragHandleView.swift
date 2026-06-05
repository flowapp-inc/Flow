import AppKit
import SwiftUI

struct WindowDragHandleView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowDragHandleNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowDragHandleNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
