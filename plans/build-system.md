# Build system

Copied from Review (which copied uncurl). No Xcode project, no `xcodebuild`.
`swift build` compiles; `build.sh` bundles and signs; `make` orchestrates.

## The pieces

- **`Package.swift`** — `PedalboardCore`, the two executables, one test target.
  Swift 6 language mode.
- **`build.sh`** — `swift build` → assemble `build/Pedalboard Dev.app` or
  `build/Pedalboard.app` (Info.plist placeholders substituted, `PkgInfo`, the
  `pedal` CLI in `Contents/MacOS`, the icon) → codesign, falling back to ad-hoc.
- **`Resources/Info.plist`** — `LSUIElement` is set: no Dock icon, no app menu.
- **`scripts/make-icon.swift`** — draws the stompbox icon in CoreGraphics;
  `--dev` adds the DEV band.
- **`scripts/make-signing-cert.sh`** — optional `pedalboard-dev` self-signed
  identity, so the designated requirement (and the Open at Login
  registration) survives rebuilds.

## Two copies: dev and installed

|              | dev (default)                | installed                        |
|--------------|------------------------------|----------------------------------|
| bundle       | `build/Pedalboard Dev.app`   | `/Applications/Pedalboard.app`   |
| bundle id    | `dev.pedalboard.app.dev`     | `dev.pedalboard.app`             |
| defaults     | that bundle id's domain      | that bundle id's domain          |
| icon         | DEV band                     | plain                            |
| built by     | any `make` / `make run`      | `make install` only              |

`build.sh` passes `-Xswiftc -DPEDALBOARD_INSTALLED` for the installed variant,
and `AppVariant.current` reads it; the two must agree on names. So
`./.build/debug/pedal` is a dev CLI and drives the dev app's settings; the
`pedal` inside the installed bundle drives the installed one.

Both variants run side by side with their own status items. They can fight:
each re-mutes what the other restores. Keep only one engaged at a time.

**`make install` → `scripts/promote.sh`.** Fetches `origin/main` into
`~/Library/Caches/Pedalboard/promote`, builds the installed variant there,
quits the running `Pedalboard.app` (which unmutes everything on the way out),
replaces `/Applications/Pedalboard.app`, and opens it.
