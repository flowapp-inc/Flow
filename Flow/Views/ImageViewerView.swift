import AppKit
import SwiftUI

struct ImageViewerView: View {
    @EnvironmentObject private var preferences: EditorPreferences
    @ObservedObject var document: EditorDocument

    @State private var zoom: CGFloat = 1
    @State private var fitsToWindow = true

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        content
        .background(Color(nsColor: theme.background))
    }

    @ViewBuilder
    private var content: some View {
        if let data = document.imageData, let nsImage = NSImage(data: data) {
            GeometryReader { proxy in
                let naturalSize = document.imagePixelSize ?? nsImage.size
                let availableSize = CGSize(
                    width: max(1, proxy.size.width - 56),
                    height: max(1, proxy.size.height - 86)
                )
                let scale = displayScale(for: naturalSize, available: availableSize)
                let displaySize = CGSize(
                    width: max(1, naturalSize.width) * scale,
                    height: max(1, naturalSize.height) * scale
                )

                VStack(spacing: 0) {
                    ImageViewerToolbar(
                        document: document,
                        zoom: $zoom,
                        fitsToWindow: $fitsToWindow,
                        displayedScale: scale
                    )

                    ScrollView([.horizontal, .vertical]) {
                        ZStack {
                            checkerboard
                                .frame(width: displaySize.width + 28, height: displaySize.height + 28)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            Image(nsImage: nsImage)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: displaySize.width, height: displaySize.height)
                                .shadow(color: .black.opacity(theme.isDark ? 0.32 : 0.12), radius: 16, x: 0, y: 8)
                        }
                        .frame(
                            minWidth: proxy.size.width,
                            minHeight: max(1, proxy.size.height - 30),
                            alignment: .center
                        )
                        .padding(28)
                    }
                    .background(Color(nsColor: theme.editorSurface))
                }
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "photo")
                    .font(.system(size: 34, weight: .medium))
                Text("Unable to preview image")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color(nsColor: theme.mutedText))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: theme.editorSurface))
        }
    }

    private var checkerboard: some View {
        Canvas { context, size in
            let tile: CGFloat = 12
            let light = Color(nsColor: theme.background.withAlpha(theme.isDark ? 0.78 : 0.90))
            let dark = Color(nsColor: theme.gutterText.withAlpha(theme.isDark ? 0.16 : 0.10))
            for row in 0...Int(size.height / tile) {
                for column in 0...Int(size.width / tile) {
                    let rect = CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                    context.fill(Path(rect), with: .color((row + column).isMultiple(of: 2) ? light : dark))
                }
            }
        }
    }

    private func displayScale(for naturalSize: CGSize, available: CGSize) -> CGFloat {
        let naturalWidth = max(1, naturalSize.width)
        let naturalHeight = max(1, naturalSize.height)

        if fitsToWindow {
            return min(available.width / naturalWidth, available.height / naturalHeight, 1)
        }

        return zoom
    }
}

private struct ImageViewerToolbar: View {
    @EnvironmentObject private var preferences: EditorPreferences
    @ObservedObject var document: EditorDocument
    @Binding var zoom: CGFloat
    @Binding var fitsToWindow: Bool
    let displayedScale: CGFloat

    private var theme: FlowTheme { preferences.theme }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(nsColor: theme.mutedText))

            Text(metadata)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(nsColor: theme.mutedText))
                .lineLimit(1)

            Spacer()

            Button {
                applyZoomMultiplier(1 / 1.25)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.plain)
            .help("Zoom Out")

            Text(zoomLabel)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(nsColor: theme.text))
                .frame(width: 46)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(nsColor: theme.editorSurface))
                )

            Button {
                fitsToWindow = true
            } label: {
                Text("Fit")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Fit to Window")

            Button {
                zoom = 1
                fitsToWindow = false
            } label: {
                Text("1:1")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Actual Size")

            Button {
                applyZoomMultiplier(1.25)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.plain)
            .help("Zoom In")
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Color(nsColor: theme.background))
    }

    private var metadata: String {
        let size = document.imagePixelSize.map { "\(Int($0.width)) x \(Int($0.height))" } ?? "image"
        let bytes = ByteCountFormatter.string(fromByteCount: Int64(document.byteCount), countStyle: .file)
        return "\(document.imageFormat ?? "Image")  \(size)  \(bytes)"
    }

    private var zoomLabel: String {
        "\(Int((displayedScale * 100).rounded()))%"
    }

    private func applyZoomMultiplier(_ multiplier: CGFloat) {
        let base = fitsToWindow ? displayedScale : zoom
        zoom = min(8, max(0.05, base * multiplier))
        fitsToWindow = false
    }
}
