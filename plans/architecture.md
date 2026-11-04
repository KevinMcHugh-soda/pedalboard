# Architecture

## Targets

| Target | Kind | Holds |
|---|---|---|
| `PedalboardCore` | library | `AudioHardware` protocol, `CoreAudioHardware`, `Pedal`, `PedalStore`, `AppVariant` |
| `PedalboardApp` | executable | `AppDelegate`, `StatusItemController`, `MixerRow` (the per-mic M/S row), `AboutPanel` |
| `pedal` | executable | The CLI, `Sources/PedalboardCLI` |
| `PedalboardCoreTests` | tests | `Pedal` against a fake `AudioHardware` |

**Layering rule:** `PedalboardCore` imports no SwiftUI or AppKit (`make
lint-layers`, part of `make check`). CoreAudio is allowed there. So the rules
are testable without a GUI, and the CLI drives exactly what the app does.

## Moving parts

- **`AudioHardware`** — list input devices, read/write mute and volume, and
  report changes. `CoreAudioHardware` is the real HAL; tests fake it.
- **`Pedal`** — the switch. One method, `reconcile()`, makes the hardware
  match the rules and runs on every click, live-list change, device
  appearance, and mute/volume change from any app. See muting.md.
- **`PedalStore`** — the engaged flag, each device's original setting, and
  the keep-live choices, in UserDefaults under the variant's bundle id. The
  app and the CLI read the same domain, so `pedal on` moves the running app.
- **`StatusItemController`** — AppKit `NSStatusItem`. A left click toggles;
  a right-click (or Control/Option-click) attaches the menu just long enough
  to open it. SwiftUI's `MenuBarExtra` was not used because it cannot tell
  the two clicks apart.
- **`PedalboardApp`** — a SwiftUI `App` with an empty `Settings` scene and an
  `NSApplicationDelegateAdaptor`; `LSUIElement` keeps it out of the Dock.

## Permissions

None. Mute and volume are device properties, and nothing opens an input
stream, so no microphone (TCC) prompt is involved. No sandbox, no
entitlements.
