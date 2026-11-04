# Pedalboard — agent instructions

Pedalboard is a macOS menu bar app: one click mutes every microphone except the ones marked
live (by default the built-in mic), so Zoom or Slack on an external mic hear nothing while
Claude on the built-in mic still hears you. Click again and every mic goes back as it was.

## Documentation conventions

* Keep a master PLAN.md as an index to the documentation you make for this codebase.

* Store specific in-depth documentation in plans/whatever.md.

* Record progress in PROGRESS.md. I should be able to tell a future agent "read PLAN.md and
  PROGRESS.md" and trust it's up to speed with this codebase.

* Never name a doc `claude.md` in any casing. The filesystem is case-insensitive, so Claude
  Code loads it as that directory's `CLAUDE.md` instructions.

## Skills

Three skills belong in `.claude/skills/` — use them. They are **not** committed: two of the
three carry no licence. `README.md` has the commands to fetch them.

* **swiftui-pro** — before and after deciding on SwiftUI code.
* **macos-design** — the UI should feel like a native macOS menu bar utility. Keep it simple.
* **swift** (Airbnb Swift Style Guide) — for any `.swift` file, in every target. The toolchain
  is Swift 6.1, which does not support raw-identifier test names: write
  `@Test("Sentence") func sentence()` instead.

`SWIFTUI-RULES.md` in the repo root is the house style and takes precedence where it conflicts.

Ask before adding a third-party dependency.

## Build

**This machine has Command Line Tools only** — `xcodebuild` does not exist here, so never reach
for it. `swift build` compiles; `build.sh` bundles and signs.

* `make check` — compile + layering gate; run after every change
* `make test` — `swift test`; the muting rules against a fake audio system, no GUI
* `make run` — build, bundle, sign, launch `build/Pedalboard Dev.app`
* `./.build/debug/pedal list` — every input device, its live/muted state and what the hardware
  reports right now. `pedal on` / `pedal off` drive the same switch as the app (they share the
  dev defaults domain), and a running dev app follows along.
* **Two copies of the app.** Everything you build is "Pedalboard Dev" (bundle id
  `dev.pedalboard.app.dev`, DEV icon, its own defaults). The user's copy is
  `/Applications/Pedalboard.app`, built from `origin/main` by `make install`. **Never run
  `make install`, and never quit or launch `/Applications/Pedalboard.app`** — quitting it
  unmutes the user's meeting mic. See plans/build-system.md.
* **Muting is real.** `pedal on` and the app's click mute the user's actual devices. Keep
  manual tests short and always end with `pedal off`.
* The menu bar cannot be screenshotted from an agent shell (no Screen Recording permission).
  Verify behaviour through `pedal list` and the hardware state instead.

## Architecture

`PedalboardCore` holds everything but the menu bar: the CoreAudio wrapper and the
engage/release rules. No SwiftUI or AppKit there (`make check` enforces it). See
plans/architecture.md and plans/muting.md.

## Git

* Never commit directly to `main` — always a feature branch.
* You may push PRs, but you MUST NOT ever merge them yourself to main.
