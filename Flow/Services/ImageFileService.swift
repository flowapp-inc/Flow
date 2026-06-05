import AppKit
import Foundation
import UniformTypeIdentifiers

struct LoadedImageFile {
    let url: URL
    let data: Data
    let byteCount: Int
    let pixelSize: CGSize?
    let format: String
}

enum ImageFileService {
    enum ImageError: LocalizedError {
        case unsupported(URL)
        case unableToDecode(URL)
        case tooLarge(URL, Int)

        var errorDescription: String? {
            switch self {
            case .unsupported(let url):
                "\(url.lastPathComponent) is not a supported image type."
            case .unableToDecode(let url):
                "Flow could not decode \(url.lastPathComponent) as an image."
            case .tooLarge(let url, let byteCount):
                "\(url.lastPathComponent) is too large to preview safely (\(ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)))."
            }
        }
    }

    private static let maxPreviewBytes = 120 * 1024 * 1024
    private static let supportedExtensions: Set<String> = [
        "png",
        "jpg",
        "jpeg",
        "webp",
        "gif",
        "tif",
        "tiff",
        "bmp",
        "heic",
        "heif",
        "ico",
        "icns"
    ]

    static func isSupportedImage(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if supportedExtensions.contains(ext) {
            return true
        }
        return UTType(filenameExtension: ext)?.conforms(to: .image) ?? false
    }

    static func load(url: URL) throws -> LoadedImageFile {
        guard isSupportedImage(url) else {
            throw ImageError.unsupported(url)
        }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let byteCount = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if byteCount > maxPreviewBytes {
            throw ImageError.tooLarge(url, byteCount)
        }

        let data = try Data(contentsOf: url)
        guard let image = NSImage(data: data), image.size.width > 0, image.size.height > 0 else {
            throw ImageError.unableToDecode(url)
        }

        return LoadedImageFile(
            url: url,
            data: data,
            byteCount: data.count,
            pixelSize: pixelSize(for: image),
            format: formatName(for: url)
        )
    }

    private static func pixelSize(for image: NSImage) -> CGSize? {
        if let representation = image.representations.max(by: { lhs, rhs in
            lhs.pixelsWide * lhs.pixelsHigh < rhs.pixelsWide * rhs.pixelsHigh
        }), representation.pixelsWide > 0, representation.pixelsHigh > 0 {
            return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        }
        return image.size
    }

    private static func formatName(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "JPEG"
        case "tif", "tiff": return "TIFF"
        case "heic": return "HEIC"
        case "heif": return "HEIF"
        case "webp": return "WebP"
        case "gif": return "GIF"
        case "bmp": return "BMP"
        case "ico": return "ICO"
        case "icns": return "ICNS"
        default: return ext.uppercased()
        }
    }
}
