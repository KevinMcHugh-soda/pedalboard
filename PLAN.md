# Pedalboard

A menu bar switch that mutes every microphone except the live ones, in one
click, so a meeting on an external mic hears nothing while Claude on the
built-in mic still hears you.

Built on the same setup as [Review](../review) and [uncurl](../uncurl):
SwiftPM, a Makefile, and no Xcode IDE.

## Documentation index

| Document | Covers |
|---|---|
| [plans/architecture.md](plans/architecture.md) | Targets, layering rule, the app's moving parts |
| [plans/muting.md](plans/muting.md) | How devices are muted and restored, and the edge cases |
| [plans/build-system.md](plans/build-system.md) | Makefile, build.sh, signing, the dev and installed variants |
| [SWIFTUI-RULES.md](SWIFTUI-RULES.md) | House SwiftUI style — takes precedence where it conflicts |
| [PROGRESS.md](PROGRESS.md) | What is built, what is next |

## Quick start

```sh
make check
make test
make run
./.build/debug/pedal list
```

## Milestones

1. ✅ **One-click mute** — menu bar toggle, keep-live list, restore on release
   and quit, re-mute against other apps, hot-plug, crash recovery, `pedal` CLI
2. ☐ **Global hotkey** — toggle without the mouse
