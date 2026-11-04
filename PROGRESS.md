# Progress

Read this with [PLAN.md](PLAN.md) to get up to speed.

## Milestone 1 — one-click mute ✅

Click the menu bar icon: every input device that is not live is muted; click
again and each is restored. Right-click for the keep-live list, Open at Login,
About and Quit.

**Verified on this machine (macOS 15.8.2, Swift 6.1.2, Command Line Tools only),
2026-11-03:**

- `make check` — compiles with no warnings; layering clean
- `make test` — 11 tests pass (`PedalTests`, against a fake audio system)
- `make build` — `build/Pedalboard Dev.app` builds and signs ad-hoc (no
  `pedalboard-dev` identity yet), launches with no Dock icon
- Against the real HAL, with the devices present (built-in mic, Microsoft
  Teams Audio, ZoomAudioDevice — no external mic was plugged in):
  - the built-in mic's mute switch reads, writes and reads back correctly
    (probed directly, then restored)
  - `pedal on` takes ZoomAudioDevice's input volume to 0 and leaves the
    built-in mic live; `pedal off` restores 100%
  - with the app running and engaged, setting ZoomAudioDevice back to 100%
    from another process was undone within a second
  - quitting the app (AppleScript `quit`) restored ZoomAudioDevice to 100%
    and left the pedal off
  - Microsoft Teams Audio accepts a mute write and stays unmuted; it is
    reported as "the device ignored its mute switch"

**Not verified:**

- The status item itself — icon, tint, menu — has not been seen: an agent
  shell cannot screenshot the menu bar.
- A real USB/external mic. Its mute switch or volume goes through the same
  code path as the devices above, but none was attached.
- Open at Login (`SMAppService.mainApp`) — not toggled.

## Next

- A global hotkey (Carbon `RegisterEventHotKey` needs no permission).
