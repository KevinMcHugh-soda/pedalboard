import CoreAudio
import Foundation

/// A CoreAudio call that failed, with the OSStatus it returned.
public struct AudioError: Error, CustomStringConvertible {
    public let operation: String
    public let status: OSStatus

    public var description: String { "\(operation) failed (OSStatus \(status))" }
}

/// `AudioHardware` over the real CoreAudio HAL.
///
/// Mute and volume are device properties, so they apply to every app
/// recording from the device at once — which is the point: Zoom cannot
/// un-mute a device it does not own the switch for. Changing them needs no
/// microphone permission, because nothing here opens an input stream.
@MainActor
public final class CoreAudioHardware: AudioHardware {
    private typealias Listener = (object: AudioObjectID, address: AudioObjectPropertyAddress, block: AudioObjectPropertyListenerBlock)

    private var systemListeners: [Listener] = []
    private var deviceListeners: [Listener] = []
    private var handler: (@MainActor () -> Void)?

    public init() {}

    // MARK: Devices

    public func inputDevices() -> [InputDevice] {
        guard let ids = try? Self.deviceIDs() else { return [] }
        return ids.compactMap(Self.inputDevice)
    }

    private static func deviceIDs() throws -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        try check("list devices", AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size))
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        try check("list devices", AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids))
        return ids
    }

    private static func inputDevice(_ id: AudioObjectID) -> InputDevice? {
        let channels = inputChannelCount(id)
        guard channels > 0, let uid = string(kAudioDevicePropertyDeviceUID, of: id) else { return nil }
        let name = string(kAudioObjectPropertyName, of: id) ?? uid
        let transport: UInt32 = scalar(kAudioDevicePropertyTransportType, of: id, scope: kAudioObjectPropertyScopeGlobal) ?? 0
        let control: InputDevice.Control =
            if !settableElements(kAudioDevicePropertyMute, of: id, channels: channels).isEmpty {
                .muteSwitch
            } else if !settableElements(kAudioDevicePropertyVolumeScalar, of: id, channels: channels).isEmpty {
                .volume
            } else {
                .none
            }
        return InputDevice(
            id: id, uid: uid, name: name, isBuiltIn: transport == kAudioDeviceTransportTypeBuiltIn, control: control)
    }

    private static func inputChannelCount(_ id: AudioObjectID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, raw) == noErr else { return 0 }
        let buffers = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    // MARK: Mute and volume

    public func isMuted(_ device: InputDevice) -> Bool {
        let elements = Self.settableElements(kAudioDevicePropertyMute, of: device.id, channels: Self.inputChannelCount(device.id))
        guard !elements.isEmpty else { return false }
        return elements.allSatisfy { (Self.scalar(kAudioDevicePropertyMute, of: device.id, element: $0) as UInt32?) == 1 }
    }

    public func setMuted(_ muted: Bool, on device: InputDevice) throws {
        let elements = Self.settableElements(kAudioDevicePropertyMute, of: device.id, channels: Self.inputChannelCount(device.id))
        for element in elements {
            try Self.setScalar(UInt32(muted ? 1 : 0), kAudioDevicePropertyMute, of: device.id, element: element)
        }
    }

    /// The first settable element's volume. Microphones keep their channels
    /// level, so one value stands for all of them.
    public func volume(of device: InputDevice) -> Float {
        let elements = Self.settableElements(kAudioDevicePropertyVolumeScalar, of: device.id, channels: Self.inputChannelCount(device.id))
        guard let first = elements.first else { return 0 }
        return Self.scalar(kAudioDevicePropertyVolumeScalar, of: device.id, element: first) ?? 0
    }

    public func setVolume(_ volume: Float, on device: InputDevice) throws {
        let elements = Self.settableElements(kAudioDevicePropertyVolumeScalar, of: device.id, channels: Self.inputChannelCount(device.id))
        for element in elements {
            try Self.setScalar(Float32(volume), kAudioDevicePropertyVolumeScalar, of: device.id, element: element)
        }
    }

    /// Where a device exposes `selector` on its input side: the main element
    /// if it has one there, otherwise each channel that does.
    private static func settableElements(_ selector: AudioObjectPropertySelector, of id: AudioObjectID, channels: Int) -> [UInt32] {
        func settable(_ element: UInt32) -> Bool {
            var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeInput, mElement: element)
            guard AudioObjectHasProperty(id, &address) else { return false }
            var isSettable: DarwinBoolean = false
            return AudioObjectIsPropertySettable(id, &address, &isSettable) == noErr && isSettable.boolValue
        }
        if settable(kAudioObjectPropertyElementMain) { return [kAudioObjectPropertyElementMain] }
        guard channels > 0 else { return [] }
        return (1...UInt32(channels)).filter(settable)
    }

    // MARK: Change notifications

    public func observeChanges(_ handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        if systemListeners.isEmpty {
            let address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            if let listener = addListener(AudioObjectID(kAudioObjectSystemObject), address, devicesChanged: true) {
                systemListeners.append(listener)
            }
        }
        watchDevices()
    }

    /// Listens to every current input device's mute and volume, replacing the
    /// listeners on the previous set of devices.
    private func watchDevices() {
        for listener in deviceListeners {
            var address = listener.address
            AudioObjectRemovePropertyListenerBlock(listener.object, &address, DispatchQueue.main, listener.block)
        }
        deviceListeners = []
        for device in inputDevices() {
            for selector in [kAudioDevicePropertyMute, kAudioDevicePropertyVolumeScalar] {
                let address = AudioObjectPropertyAddress(
                    mSelector: selector,
                    mScope: kAudioObjectPropertyScopeInput,
                    mElement: kAudioObjectPropertyElementWildcard)
                if let listener = addListener(device.id, address, devicesChanged: false) {
                    deviceListeners.append(listener)
                }
            }
        }
    }

    private func addListener(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, devicesChanged: Bool) -> Listener? {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            // Registered on the main queue, so this is the main thread.
            MainActor.assumeIsolated {
                guard let self else { return }
                if devicesChanged { self.watchDevices() }
                self.handler?()
            }
        }
        var address = address
        guard AudioObjectAddPropertyListenerBlock(object, &address, DispatchQueue.main, block) == noErr else { return nil }
        return (object, address, block)
    }

    // MARK: Property helpers

    private static func check(_ operation: String, _ status: OSStatus) throws {
        guard status == noErr else { throw AudioError(operation: operation, status: status) }
    }

    private static func string(_ selector: AudioObjectPropertySelector, of id: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func scalar<T: BitwiseCopyable>(
        _ selector: AudioObjectPropertySelector,
        of id: AudioObjectID,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeInput,
        element: UInt32 = kAudioObjectPropertyElementMain
    ) -> T? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        var size = UInt32(MemoryLayout<T>.size)
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, pointer) == noErr else { return nil }
        return pointer.pointee
    }

    private static func setScalar<T: BitwiseCopyable>(_ value: T, _ selector: AudioObjectPropertySelector, of id: AudioObjectID, element: UInt32) throws {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeInput, mElement: element)
        var value = value
        try check(
            "set property \(selector) on device \(id)",
            AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<T>.size), &value))
    }
}
