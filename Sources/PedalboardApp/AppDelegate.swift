import AppKit
import PedalboardCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let pedal = Pedal(hardware: CoreAudioHardware(), store: DefaultsStore())
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController(pedal: pedal)
        // If the last run ended engaged without releasing — a crash, a forced
        // quit — this picks the pedal back up rather than unmuting a meeting.
        pedal.start()
    }

    /// Quitting is letting go of the pedal: nothing stays silenced with no
    /// menu bar icon left to say so.
    func applicationWillTerminate(_ notification: Notification) {
        pedal.setEngaged(false)
    }
}
