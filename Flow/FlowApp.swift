import SwiftUI

@main
struct FlowApp: App {
    @NSApplicationDelegateAdaptor(FlowAppDelegate.self) private var appDelegate
    @StateObject private var preferences: EditorPreferences
    @StateObject private var model: AppModel

    init() {
        let preferences = EditorPreferences()
        _preferences = StateObject(wrappedValue: preferences)
        _model = StateObject(wrappedValue: AppModel(preferences: preferences))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environmentObject(preferences)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            FlowCommands(model: model, preferences: preferences)
        }

        Settings {
            SettingsView()
                .environmentObject(preferences)
        }
    }
}

final class FlowAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map(URL.init(fileURLWithPath:))
        NotificationCenter.default.post(name: .flowOpenFiles, object: urls)
        sender.reply(toOpenOrPrint: .success)
    }
}
