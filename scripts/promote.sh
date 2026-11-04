#!/usr/bin/env bash
#
# promote.sh — build origin/main as the installed Pedalboard and put it in
# /Applications. `make install` runs this.
#
# It never builds the checkout it is run from: main is fetched into a worktree
# of its own (kept between runs so builds are incremental), so your branch and
# uncommitted edits make no difference. The running Pedalboard is asked to quit,
# replaced, and opened again.
#
# For you to run. Agents build and test the dev variant only.
#
# Environment:
#   PROMOTE_WORKTREE  where main is built (default ~/Library/Caches/Pedalboard/promote)
#   PROMOTE_REF       what to build (default origin/main)
#
set -euo pipefail

REPO="$(git rev-parse --show-toplevel)"
WORKTREE="${PROMOTE_WORKTREE:-$HOME/Library/Caches/Pedalboard/promote}"
REF="${PROMOTE_REF:-origin/main}"
DEST="/Applications/Pedalboard.app"
BUNDLE_ID="dev.pedalboard.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

echo "→ fetching $REF"
git -C "$REPO" fetch --quiet origin main

if [ -e "$WORKTREE/.git" ]; then
	git -C "$WORKTREE" checkout --quiet --force --detach "$REF"
	# Untracked files go; ignored ones (.build, build) stay, so the build is
	# incremental.
	git -C "$WORKTREE" clean -fdq
else
	git -C "$REPO" worktree prune
	mkdir -p "$(dirname "$WORKTREE")"
	git -C "$REPO" worktree add --quiet --detach "$WORKTREE" "$REF"
fi
COMMIT="$(git -C "$WORKTREE" rev-parse --short HEAD)"
echo "→ building $COMMIT ($(git -C "$WORKTREE" log -1 --format=%s))"

make -C "$WORKTREE" release VARIANT=installed COMMIT="$COMMIT"
BUILT="$WORKTREE/build/Pedalboard.app"
[ -d "$BUILT" ] || { echo "✗ $BUILT missing — build failed?" >&2; exit 1; }

# Quit the installed copy through AppKit, so it releases the pedal and
# restores every mic on the way out. Pedalboard Dev.app is left running.
running() { pgrep -qf "/Pedalboard\.app/Contents/MacOS/PedalboardApp"; }
if running; then
	echo "→ quitting the running Pedalboard"
	osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
	for _ in $(seq 50); do
		running || break
		sleep 0.2
	done
	if running; then
		echo "✗ Pedalboard is still running — it may be asking something. Quit it and run make install again." >&2
		exit 1
	fi
fi

rm -rf "$DEST"
ditto "$BUILT" "$DEST"
"$LSREGISTER" -f "$DEST"
echo "✓ installed $COMMIT at $DEST"

open "$DEST"
