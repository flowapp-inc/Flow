import Foundation

struct FileNode: Identifiable, Hashable {
    let id: URL
    let url: URL
    let isDirectory: Bool
    let children: [FileNode]?

    var name: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }

    static func load(root: URL, maxDepth: Int = 5) -> [FileNode] {
        children(for: root, depth: 0, maxDepth: maxDepth)
    }

    static func flatFiles(root: URL, maxDepth: Int = 8) -> [FileNode] {
        flatten(children(for: root, depth: 0, maxDepth: maxDepth))
    }

    private static func children(for url: URL, depth: Int, maxDepth: Int) -> [FileNode] {
        guard depth <= maxDepth,
              let urls = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: [.skipsPackageDescendants]
              ) else {
            return []
        }

        return urls
            .filter { item in
                !ignoredNames.contains(item.lastPathComponent)
            }
            .sorted { lhs, rhs in
                let lhsDirectory = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let rhsDirectory = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if lhsDirectory != rhsDirectory { return lhsDirectory && !rhsDirectory }
                return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }
            .map { item in
                let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return FileNode(
                    id: item,
                    url: item,
                    isDirectory: isDirectory,
                    children: isDirectory ? children(for: item, depth: depth + 1, maxDepth: maxDepth) : nil
                )
            }
    }

    private static func flatten(_ nodes: [FileNode]) -> [FileNode] {
        nodes.flatMap { node in
            if node.isDirectory {
                return flatten(node.children ?? [])
            }
            return [node]
        }
    }

    private static let ignoredNames: Set<String> = [
        ".DS_Store",
        ".git",
        ".svn",
        ".hg",
        "node_modules",
        ".build",
        "DerivedData",
        "build",
        "dist"
    ]
}
