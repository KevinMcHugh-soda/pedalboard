import AppKit

/// The standard About panel, with the commit the build came from in place of
/// the build number: "Version 0.1.0 (2f3ee44)".
@MainActor
enum AboutPanel {
    static func show() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let commit = info["PedalboardCommit"] as? String ?? "unknown"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationVersion: version, .version: commit])
    }
}
