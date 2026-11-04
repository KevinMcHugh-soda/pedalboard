# Pedalboard

A macOS menu bar switch for your microphones. Click it and every mic goes
silent except the ones you keep live — by default the built-in one. Click again
and each comes back exactly as it was.

The point: Zoom or Slack is on your external mic, Claude is on your built-in
mic, and you want to talk to Claude without talking to the meeting — without
hunting for the mute button in whichever app it is.

- **Click** the icon to mute or unmute. Red means muted; orange means something
  that should be muted still can't be (hover for which).
- **Right-click** (or Control-/Option-click) for the menu: which mics to keep
  live, Open at Login, Quit.
- It mutes the **device**, not the app, so Zoom can't undo it — and if an app
  turns a muted mic back up (Zoom's automatic mic level does), Pedalboard turns
  it back down. Mics plugged in while muted are muted too.
- Quitting unmutes everything. If it crashes while muted, the next launch picks
  the muted state back up rather than unmuting your meeting.

Devices are muted with their hardware mute switch where they have one, or by
taking their input volume to zero (and restoring it) where they don't. A few
virtual devices offer neither; the menu says so.

SwiftUI/AppKit, SwiftPM and a Makefile. No Xcode project — this builds on a
machine with Command Line Tools only.

## Building

```sh
make check      # compile + layering gate
make test       # swift test, no GUI needed
make run        # build, bundle, sign, launch "Pedalboard Dev"
make install    # build origin/main as /Applications/Pedalboard.app, and relaunch it
```

A build from a checkout is **Pedalboard Dev** — DEV on its icon, its own
settings — so testing a change never disturbs the copy in your menu bar. Only
`make install` replaces `/Applications/Pedalboard.app`.

```sh
pedal list      # every input device: live or muted, and what the hardware reports
pedal on        # mute every mic that isn't live
pedal off       # put them all back
pedal toggle
```

Optionally, `./scripts/make-signing-cert.sh` creates a self-signed identity so
macOS stops treating each build as a different program (it keeps Open at Login
attached across rebuilds).

## Credits

The project structure — `Makefile`, `build.sh`, `Resources/Info.plist`,
`SWIFTUI-RULES.md`, the dev/installed variants and the `PLAN.md`/`PROGRESS.md`
convention — is copied from Review, which copied uncurl, which began as a copy
of [tqbf/swiftui-app](https://github.com/tqbf/swiftui-app).

Development leans on three agent skills, which are **not** redistributed in this
repository. Install them into `.claude/skills/` yourself:

```sh
mkdir -p .claude/skills
git clone --depth 1 https://github.com/ceorkm/macos-design-skill /tmp/mds \
  && mkdir -p .claude/skills/macos-design \
  && cp -R /tmp/mds/SKILL.md /tmp/mds/references .claude/skills/macos-design/
git clone --depth 1 https://github.com/twostraws/swiftui-agent-skill /tmp/sas \
  && mkdir -p .claude/skills/swiftui-pro \
  && cp -R /tmp/sas/swiftui-pro/SKILL.md /tmp/sas/swiftui-pro/references .claude/skills/swiftui-pro/
mkdir -p .claude/skills/swift \
  && curl -sSL https://swift.airbnb.tech/SKILL.md -o .claude/skills/swift/SKILL.md
```

No third-party dependencies.
