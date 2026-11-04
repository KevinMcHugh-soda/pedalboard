import SwiftUI

// Not `main.swift` — see the note in Sources/PedalboardCLI/PedalCommand.swift.
@main
struct PedalboardApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        // Everything lives in the status item, which AppKit owns: SwiftUI's
        // MenuBarExtra cannot tell a click from a right-click, and the click
        // has to toggle. An app needs one scene, and an empty Settings scene
        // never shows — LSUIElement leaves it no menu to open from.
        Settings {
            EmptyView()
        }
    }
}
