import PedalboardCore
import Testing

@MainActor
final class FakeHardware: AudioHardware {
    var devices: [InputDevice]
    var muted: [String: Bool] = [:]
    var volumes: [String: Float] = [:]
    var writes = 0
    var ignoresMute: Set<String> = []

    init(_ devices: [InputDevice]) {
        self.devices = devices
        for device in devices { volumes[device.uid] = 0.8 }
    }

    func inputDevices() -> [InputDevice] { devices }
    func isMuted(_ device: InputDevice) -> Bool { muted[device.uid] ?? false }
    func setMuted(_ muted: Bool, on device: InputDevice) throws {
        writes += 1
        if !ignoresMute.contains(device.uid) { self.muted[device.uid] = muted }
    }
    func volume(of device: InputDevice) -> Float { volumes[device.uid] ?? 0 }
    func setVolume(_ volume: Float, on device: InputDevice) throws {
        writes += 1
        volumes[device.uid] = volume
    }
    func observeChanges(_ handler: @escaping @MainActor () -> Void) {}
}

let builtIn = InputDevice(id: 1, uid: "builtin", name: "MacBook Pro Microphone", isBuiltIn: true, control: .volume)
let usb = InputDevice(id: 2, uid: "usb", name: "Shure MV7", isBuiltIn: false, control: .muteSwitch)
let interface = InputDevice(id: 3, uid: "interface", name: "Scarlett 2i2", isBuiltIn: false, control: .volume)
let virtual = InputDevice(id: 4, uid: "virtual", name: "ZoomAudioDevice", isBuiltIn: false, control: .none)

@MainActor
struct PedalTests {
    @Test("Engaging mutes every device but the built-in mic")
    func engageMutesAllButBuiltIn() {
        let hardware = FakeHardware([builtIn, usb, interface])
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setEngaged(true)
        #expect(hardware.muted["usb"] == true)
        #expect(hardware.volumes["interface"] == 0)
        #expect(hardware.volumes["builtin"] == 0.8)
        #expect(hardware.muted["builtin"] == nil)
    }

    @Test("Releasing puts every device back as it was")
    func releaseRestores() {
        let hardware = FakeHardware([builtIn, usb, interface])
        hardware.volumes["interface"] = 0.35
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setEngaged(true)
        pedal.setEngaged(false)
        #expect(hardware.muted["usb"] == false)
        #expect(hardware.volumes["interface"] == 0.35)
    }

    @Test("A device that was already muted stays muted on release")
    func alreadyMutedStaysMuted() {
        let hardware = FakeHardware([builtIn, usb])
        hardware.muted["usb"] = true
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setEngaged(true)
        pedal.setEngaged(false)
        #expect(hardware.muted["usb"] == true)
    }

    @Test("Another app turning a muted device back up is undone")
    func reassertsAgainstOtherApps() {
        let hardware = FakeHardware([builtIn, interface])
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setEngaged(true)
        hardware.volumes["interface"] = 0.6
        pedal.reconcile()
        #expect(hardware.volumes["interface"] == 0)
        pedal.setEngaged(false)
        #expect(hardware.volumes["interface"] == 0.8)
    }

    @Test("Reconciling an already-muted device writes nothing")
    func idempotent() {
        let hardware = FakeHardware([builtIn, usb, interface])
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setEngaged(true)
        let writes = hardware.writes
        pedal.reconcile()
        #expect(hardware.writes == writes)
    }

    @Test("Making a muted device live while engaged restores it")
    func liveWhileEngaged() {
        let hardware = FakeHardware([builtIn, usb])
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setEngaged(true)
        pedal.setLive(true, for: usb)
        #expect(hardware.muted["usb"] == false)
        pedal.setLive(false, for: builtIn)
        #expect(hardware.volumes["builtin"] == 0)
    }

    @Test("A device plugged in while engaged is muted")
    func hotPlug() {
        let hardware = FakeHardware([builtIn])
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setEngaged(true)
        hardware.devices.append(usb)
        pedal.reconcile()
        #expect(hardware.muted["usb"] == true)
    }

    @Test("A device unplugged while muted is restored when it returns")
    func unplugWhileMuted() {
        let hardware = FakeHardware([builtIn, interface])
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setEngaged(true)
        hardware.devices = [builtIn]
        pedal.setEngaged(false)
        #expect(hardware.volumes["interface"] == 0)
        hardware.devices = [builtIn, interface]
        pedal.reconcile()
        #expect(hardware.volumes["interface"] == 0.8)
    }

    @Test("A relaunch after a crash stays engaged and still knows the originals")
    func survivesRelaunch() {
        let hardware = FakeHardware([builtIn, interface])
        hardware.volumes["interface"] = 0.5
        let store = MemoryStore()
        Pedal(hardware: hardware, store: store).setEngaged(true)

        let relaunched = Pedal(hardware: hardware, store: store)
        relaunched.reconcile()
        #expect(relaunched.isEngaged)
        #expect(hardware.volumes["interface"] == 0)
        relaunched.setEngaged(false)
        #expect(hardware.volumes["interface"] == 0.5)
    }

    @Test("A device with no control is reported as still hearing you")
    func leaks() {
        let hardware = FakeHardware([builtIn, usb, virtual])
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.reconcile()
        #expect(pedal.leaks.isEmpty)
        pedal.setEngaged(true)
        #expect(pedal.leaks == [virtual])
        #expect(pedal.state(of: virtual) == .unsilenceable)
        #expect(pedal.state(of: usb) == .silenced)
        #expect(pedal.state(of: builtIn) == .live)
    }

    @Test("A device that ignores its mute switch is reported, not claimed muted")
    func ignoredMute() {
        let hardware = FakeHardware([builtIn, usb])
        hardware.ignoresMute = ["usb"]
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setEngaged(true)
        #expect(pedal.failures["usb"] != nil)
        #expect(pedal.leaks == [usb])
    }

    @Test("A device that ignores its mute switch is not written again on every change")
    func ignoredMuteIsNotRetried() {
        let hardware = FakeHardware([builtIn, usb])
        hardware.ignoresMute = ["usb"]
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setEngaged(true)
        let writes = hardware.writes
        pedal.reconcile()
        pedal.reconcile()
        #expect(hardware.writes == writes)
        #expect(pedal.leaks == [usb])
    }

    @Test("With one live mic at a time, picking a mic mutes the one that was live")
    func oneLiveMicSwitches() {
        let hardware = FakeHardware([builtIn, usb, interface])
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setOneLiveMic(true)
        pedal.setEngaged(true)
        pedal.setLive(true, for: usb)
        #expect(pedal.devices.filter(pedal.isLive) == [usb])
        #expect(hardware.muted["usb"] == false)
        #expect(hardware.volumes["builtin"] == 0)
    }

    @Test("Without it, picking a mic keeps the others live")
    func severalLiveMics() {
        let hardware = FakeHardware([builtIn, usb])
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setLive(true, for: usb)
        #expect(pedal.devices.filter(pedal.isLive) == [builtIn, usb])
    }

    @Test("Turning it on with several mics live keeps only the built-in one")
    func turningOnKeepsBuiltIn() {
        let hardware = FakeHardware([usb, builtIn, interface])
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setLive(true, for: usb)
        pedal.setLive(true, for: interface)
        pedal.setOneLiveMic(true)
        #expect(pedal.devices.filter(pedal.isLive) == [builtIn])
    }

    @Test("A mic that was live while unplugged comes back not live")
    func unpluggedMicNotLive() {
        let hardware = FakeHardware([builtIn, usb])
        let pedal = Pedal(hardware: hardware, store: MemoryStore())
        pedal.setOneLiveMic(true)
        pedal.setLive(true, for: usb)
        hardware.devices = [builtIn]
        pedal.reconcile()
        pedal.setLive(true, for: builtIn)
        hardware.devices = [builtIn, usb]
        pedal.reconcile()
        #expect(pedal.devices.filter(pedal.isLive) == [builtIn])
    }
}
