import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: EditorPreferences

    var body: some View {
        Form {
            Picker("Theme", selection: $preferences.themeID) {
                ForEach(FlowTheme.all) { theme in
                    Text(theme.name).tag(theme.id)
                }
            }

            TextField("Editor Font", text: $preferences.fontName)
            Stepper(value: $preferences.fontSize, in: 10...28, step: 1) {
                Text("Font Size: \(Int(preferences.fontSize))")
            }

            Toggle("Word Wrap", isOn: $preferences.wordWrap)
            Toggle("Line Numbers", isOn: $preferences.showLineNumbers)
            Toggle("Minimap", isOn: $preferences.showMinimap)
            Toggle("Titlebar Follows Theme", isOn: $preferences.titlebarFollowsTheme)
        }
        .padding(20)
        .frame(width: 420)
    }
}
