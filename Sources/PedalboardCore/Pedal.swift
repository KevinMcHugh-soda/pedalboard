/// The one switch: when engaged, every input device that is not live is
/// silenced; when released, each is put back as it was.
///
/// Everything goes through `reconcile()`, which makes the hardware match the
/// rules and is safe to call any time: on a click, when a device is plugged
/// in, and when another app turns a silenced device back up (Zoom's automatic
/// mic level does). Original settings are captured once, the first time a
/// device is silenced, so re-silencing never overwrites them.
@MainActor
public final class Pedal {
    /// A device that reported success setting its mute switch and is still
    /// unmuted.
    public struct IgnoredMute: Error, CustomStringConvertible {
        public var description: String { "the device ignored its mute switch" }
    }

    public enum DeviceState: Equatable, Sendable {
        /// Kept live — never touched.
        case live
        /// Silenced by Pedalboard.
        case silenced
        /// Not live, but the pedal is up.
        case open
        /// Not live, but CoreAudio offers no way to silence it.
        case unsilenceable
    }

    public private(set) var devices: [InputDevice] = []
    /// The last error per device UID, cleared when the device next succeeds.
    public private(set) var failures: [String: String] = [:]
    /// Called after every reconcile, so a UI can redraw.
    public var onChange: (@MainActor () -> Void)?

    private let hardware: AudioHardware
    private let store: PedalStore
    /// UIDs of devices that ignored a mute write this engagement. They are
    /// not written again until the pedal is next pressed: Microsoft Teams
    /// Audio posts a mute-changed notification for every ignored write, so
    /// retrying on each notification spins forever.
    private var ignoringMute: Set<String> = []

    public init(hardware: AudioHardware, store: PedalStore) {
        self.hardware = hardware
        self.store = store
    }

    /// Reconciles once, then again whenever the audio system changes.
    public func start() {
        reconcile()
        hardware.observeChanges { [weak self] in self?.reconcile() }
    }

    public var isEngaged: Bool { store.isEngaged }

    public func setEngaged(_ engaged: Bool) {
        store.isEngaged = engaged
        ignoringMute = []
        reconcile()
    }

    public func toggle() {
        setEngaged(!isEngaged)
    }

    public func isLive(_ device: InputDevice) -> Bool {
        store.liveOverrides[device.uid] ?? device.isBuiltIn
    }

    public func setLive(_ live: Bool, for device: InputDevice) {
        store.liveOverrides[device.uid] = live
        reconcile()
    }

    /// Makes `device` the only live mic and presses the pedal, so it is the
    /// one mic still hearing you. Every other mic stops being live —
    /// unplugged ones too, so an old USB mic doesn't come back live.
    public func solo(_ device: InputDevice) {
        var overrides = store.liveOverrides
        for other in hardware.inputDevices() { overrides[other.uid] = false }
        for uid in overrides.keys { overrides[uid] = false }
        overrides[device.uid] = true
        store.liveOverrides = overrides
        store.isEngaged = true
        ignoringMute = []
        reconcile()
    }

    /// Whether `device` is soloed: the pedal is down and it is the only live
    /// mic present.
    public func isSoloed(_ device: InputDevice) -> Bool {
        isEngaged && isLive(device) && devices.allSatisfy { $0.uid == device.uid || !isLive($0) }
    }

    public func state(of device: InputDevice) -> DeviceState {
        if isLive(device) { return .live }
        if device.control == .none { return .unsilenceable }
        return isEngaged ? .silenced : .open
    }

    /// Devices the pedal should silence but cannot, while it is engaged — the
    /// ones still hearing you.
    public var leaks: [InputDevice] {
        guard isEngaged else { return [] }
        return devices.filter { state(of: $0) == .unsilenceable || failures[$0.uid] != nil }
    }

    public func reconcile() {
        devices = hardware.inputDevices()
        var saved = store.savedStates
        for device in devices {
            do {
                if isEngaged, !isLive(device), device.control != .none {
                    try silence(device, saved: &saved)
                } else if let original = saved[device.uid] {
                    try restore(device, to: original)
                    saved[device.uid] = nil
                }
                failures[device.uid] = nil
            } catch {
                failures[device.uid] = String(describing: error)
            }
        }
        // A device that vanished while silenced keeps its saved state, and is
        // restored when it next appears with the pedal up.
        store.savedStates = saved
        onChange?()
    }

    private func silence(_ device: InputDevice, saved: inout [String: SavedState]) throws {
        switch device.control {
        case .muteSwitch:
            let muted = hardware.isMuted(device)
            if saved[device.uid] == nil { saved[device.uid] = .muteSwitch(wasMuted: muted) }
            if !muted {
                if ignoringMute.contains(device.uid) { throw IgnoredMute() }
                try hardware.setMuted(true, on: device)
                // Some virtual devices (Microsoft Teams Audio) accept the
                // write and stay unmuted. Say so rather than claim it.
                guard hardware.isMuted(device) else {
                    ignoringMute.insert(device.uid)
                    throw IgnoredMute()
                }
            }
        case .volume:
            let volume = hardware.volume(of: device)
            if saved[device.uid] == nil { saved[device.uid] = .volume(volume) }
            if volume > 0 { try hardware.setVolume(0, on: device) }
        case .none:
            break
        }
    }

    private func restore(_ device: InputDevice, to original: SavedState) throws {
        switch original {
        case .muteSwitch(let wasMuted):
            if hardware.isMuted(device) != wasMuted { try hardware.setMuted(wasMuted, on: device) }
        case .volume(let volume):
            try hardware.setVolume(volume, on: device)
        }
    }
}
