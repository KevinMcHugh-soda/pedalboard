# Muting

## Why the device, not the app

macOS gives no way to mute another app's capture. What it does offer is
per-device controls in the CoreAudio HAL, and those apply to every app
recording from that device. Since the meeting and Claude use *different*
devices, muting every device but Claude's does the job, and Zoom cannot undo
it from its own mute button.

## Which control

`CoreAudioHardware` looks on the input scope for, in order:

1. **`kAudioDevicePropertyMute`**, settable — on the main element, else on each
   channel. Restores exactly.
2. **`kAudioDevicePropertyVolumeScalar`**, settable — the same search. Muting
   sets 0; the first element's original volume is restored to every element
   (mic channels sit level, so one value stands for all).
3. Neither — `Control.none`. The menu says the device can't be muted and the
   icon turns orange while engaged.

Some virtual devices (Microsoft Teams Audio, as of 2026-11) report a settable
mute switch, accept the write with `noErr`, and stay unmuted. `Pedal` reads the
switch back after writing and records `IgnoredMute` as a failure, which also
shows as orange. It does not write to that device again until the pedal is
next pressed: Teams Audio posts a mute-changed notification for every ignored
write, and retrying on each one spun the app at ~30% CPU.

## The rules (`Pedal.reconcile`)

For each current input device:

- **engaged, not live, has a control** → save its original setting if none is
  saved yet, then mute it if it isn't already
- **otherwise, with a saved setting** → restore it and forget it

"Live" is the user's choice from the menu, defaulting to built-in devices
(`kAudioDeviceTransportTypeBuiltIn`).

Consequences, each covered by a test in `PedalTests`:

- Re-muting never overwrites the original, so another app raising a muted
  mic's volume is undone and release still restores the true original.
- A mic that was already muted before engaging stays muted after release.
- Reconcile writes nothing when the hardware already matches, so the change
  listener firing on Pedalboard's own writes settles immediately.
- A device unplugged while muted keeps its saved setting; it is restored when
  it next appears with the pedal up.
- The engaged flag and saved settings persist, so a relaunch after a crash
  stays muted and still knows the originals. A normal quit releases first.

## Change notifications

`CoreAudioHardware.observeChanges` listens on the main queue for
`kAudioHardwarePropertyDevices` on the system object, and for mute and volume
(wildcard element) on every input device. The per-device listeners are
replaced whenever the device list changes. Notifications are coalesced: a
burst within 100 ms becomes one reconcile.
