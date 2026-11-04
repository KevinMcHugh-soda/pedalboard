import Foundation
import PedalboardCore

// NOTE: this file must never be named `main.swift`. In a SwiftPM executable
// target that name means "top-level code", and @main then fails to compile
// with "'main' attribute cannot be used in a module that contains top-level
// code".

/// `pedal` — the app's switch without the menu bar, sharing its settings.
@main
@MainActor
enum PedalCommand {
    static let usage = """
        usage: pedal <command>

          list      every input device, whether it is live, and how it is silenced
          on        silence every device that is not live
          off       put every silenced device back as it was
          toggle    on if off, off if on
          solo MIC  keep only the device named MIC live, and turn on
          version   the build's variant
        """

    static func main() {
        let arguments = CommandLine.arguments.dropFirst()
        let hardware = CoreAudioHardware()
        let pedal = Pedal(hardware: hardware, store: DefaultsStore())
        switch arguments.first {
        case "list", nil:
            pedal.reconcile()
            list(pedal, hardware)
        case "on":
            pedal.setEngaged(true)
            list(pedal, hardware)
        case "off":
            pedal.setEngaged(false)
            list(pedal, hardware)
        case "toggle":
            pedal.toggle()
            list(pedal, hardware)
        case "solo":
            pedal.reconcile()
            let name = arguments.dropFirst().joined(separator: " ")
            let matches = pedal.devices.filter { $0.name.localizedCaseInsensitiveContains(name) }
            guard !name.isEmpty, matches.count == 1, let device = matches.first else {
                print(matches.isEmpty ? "no device matches \"\(name)\"" : "\"\(name)\" matches \(matches.map(\.name).joined(separator: ", "))")
                exit(1)
            }
            pedal.solo(device)
            list(pedal, hardware)
        case "version":
            print("\(AppVariant.current.appName) (\(AppVariant.current.bundleIdentifier))")
        default:
            print(usage)
            exit(2)
        }
    }

    private static func list(_ pedal: Pedal, _ hardware: CoreAudioHardware) {
        print("pedal: \(pedal.isEngaged ? "on — meeting mics silenced" : "off")")
        for device in pedal.devices {
            let state =
                switch pedal.state(of: device) {
                case .live: "live"
                case .silenced: "silenced"
                case .open: "open"
                case .unsilenceable: "can't be silenced"
                }
            // What the hardware says now, not what the pedal intends.
            let control =
                switch device.control {
                case .muteSwitch: hardware.isMuted(device) ? "mute switch: muted" : "mute switch: on"
                case .volume: "input volume: \(Int((hardware.volume(of: device) * 100).rounded()))%"
                case .none: "no control"
                }
            print("  \(state.padding(toLength: 18, withPad: " ", startingAt: 0)) \(device.name)  [\(control)\(device.isBuiltIn ? ", built in" : "")]")
            if let failure = pedal.failures[device.uid] {
                print("      ✗ \(failure)")
            }
        }
    }
}
