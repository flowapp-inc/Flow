# Flow

Flow is a minimal native macOS text and code editor built with SwiftUI, AppKit, and Highlightr. It is designed to stay quiet visually while still giving developers and writers the essentials: tabs, splits, search, syntax highlighting, image viewing, themes, file browsing, and fast handling for larger files.

## Requirements

- macOS 14 or newer
- Xcode 26 or newer
- XcodeGen

Install XcodeGen if needed:

```sh
brew install xcodegen
```

## Generate The Project

Flow uses `project.yml` as the source of truth for the Xcode project.

```sh
xcodegen generate
```

This creates `Flow.xcodeproj`.

## Build

```sh
xcodebuild -scheme Flow -configuration Debug -derivedDataPath .build/DerivedData -jobs 1 build
```

The built app is created at:

```text
.build/DerivedData/Build/Products/Debug/Flow.app
```

## Run

Open the built app from Finder, or run:

```sh
open .build/DerivedData/Build/Products/Debug/Flow.app
```

## App Configuration

The macOS target is sandboxed. Entitlements are defined in:

```text
Flow/Flow.entitlements
```

Enabled access:

- App Sandbox
- User-selected read/write files
- App-scoped security bookmarks for restored tabs and recent files

Project settings live in:

```text
project.yml
```

After changing build settings, entitlements, assets, packages, or target configuration, run `xcodegen generate` again.

## Main Features

- Tabbed editing with close buttons and dirty indicators
- Drag to reorder tabs
- Vertical and horizontal split editing with resizable panes
- File browser sidebar with file and folder actions
- Syntax highlighting with automatic language detection and manual override
- Format Document, smart indentation, duplicate line, toggle comment, and trim trailing whitespace
- Find and replace with case-sensitive and regex modes
- `Cmd+Shift+F` document search popup with line previews and match highlighting
- `Cmd+Shift+P` command palette for actions, themes, recent files, and view toggles
- `Cmd+L` Go to Line with immediate editor focus
- Toggleable line numbers, word wrap, and minimap
- Large File Mode for safer performance on big documents
- Image viewer for PNG, JPEG, WebP, GIF, TIFF, HEIC, BMP, and related formats
- Built-in themes: Flow Light, Flow Dark, Tokyo Night, Solarized Light, Solarized Dark, and Monokai
- Encoding and line ending detection with preservation on save

## Useful Shortcuts

| Shortcut | Action |
| --- | --- |
| `Cmd+N` | New file |
| `Cmd+O` | Open file or folder |
| `Cmd+Shift+O` | Open folder |
| `Cmd+S` | Save |
| `Cmd+W` | Close tab |
| `Cmd+P` | Quick open |
| `Cmd+Shift+P` | Command palette |
| `Cmd+F` | Find and replace |
| `Cmd+Shift+F` | Search current document |
| `Cmd+G` | Find next |
| `Cmd+Shift+G` | Find previous |
| `Cmd+L` | Go to line |
| `Cmd+Shift+I` | Format document |
| `Cmd+/` | Toggle comment |
| `Cmd+Shift+D` | Duplicate line or selection |
| `Cmd+Shift+K` | Trim trailing whitespace |
| `Cmd+\\` | Vertical split |
| `Cmd+Shift+\\` | Horizontal split |

## Notes

Large File Mode automatically reduces expensive work such as full-document highlighting, detailed minimap rendering, and live regex matching. This keeps Flow responsive when opening large source files, logs, Markdown documents, and generated text.
