/// A device that can record: anything CoreAudio lists with input channels.
public struct InputDevice: Sendable, Hashable, Identifiable {
    /// How Pedalboard silences a device. CoreAudio exposes either a mute
    /// switch, an input volume, both, or neither; the switch is preferred
    /// because it restores exactly.
    public enum Control: Sendable, Hashable {
        case muteSwitch
        case volume
        case none
    }

    /// The CoreAudio object id. It changes when a device is replugged, so
    /// anything remembered across time is keyed by `uid` instead.
    public let id: UInt32
    public let uid: String
    public let name: String
    public let isBuiltIn: Bool
    public let control: Control

    public init(id: UInt32, uid: String, name: String, isBuiltIn: Bool, control: Control) {
        self.id = id
        self.uid = uid
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.control = control
    }
}

/// The parts of the audio system Pedalboard touches. `CoreAudioHardware` is
/// the real one; tests use a fake.
@MainActor
public protocol AudioHardware: AnyObject {
    func inputDevices() -> [InputDevice]
    func isMuted(_ device: InputDevice) -> Bool
    func setMuted(_ muted: Bool, on device: InputDevice) throws
    func volume(of device: InputDevice) -> Float
    func setVolume(_ volume: Float, on device: InputDevice) throws
    /// Calls `handler` whenever a device appears or disappears, or any input
    /// device's mute or volume changes — including changes made by other apps.
    func observeChanges(_ handler: @escaping @MainActor () -> Void)
}
