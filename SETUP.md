# Setting up PomodoroBar (instructions for Claude Code)

**For the person reading this:** you don't have to do anything here yourself. Paste this sentence into Claude Code:

> Install PomodoroBar on my Mac by following https://github.com/hendrikboettcher/PomodoroBar/blob/main/SETUP.md

---

**For Claude Code.** Install PomodoroBar for someone who may never have used a terminal. Run every command yourself and say only a sentence or two per step. Nothing here needs their Mac password. Don't change anything other than what the steps below install.

Download only with `curl`, as written below. macOS refuses a copy of this app downloaded with a browser, because the app isn't signed with an Apple Developer ID.

## 1. Check the Mac

```bash
uname -m; sw_vers -productVersion
```

It needs `arm64` (an Apple chip) and macOS 13 or newer. If not, tell them it can't run on this Mac and stop.

## 2. Choose where it goes

```bash
if [ -e /Applications/PomodoroBar.app ]; then
  [ -w /Applications/PomodoroBar.app ] && [ -w /Applications ] && echo /Applications || echo "$HOME/Applications"
else
  [ -w /Applications ] && echo /Applications || echo "$HOME/Applications"
fi
```

Use the printed folder as `DEST` below. `~/Applications` is for accounts that can't change `/Applications`, for example a non-admin account. Updates only work in a folder this account can write to.

## 3. Install

Replace `DEST` with the folder from step 2:

```bash
DEST="DEST"
WORK="$(mktemp -d)"
curl -fsSL -o "$WORK/PomodoroBar.zip" https://github.com/hendrikboettcher/PomodoroBar/releases/latest/download/PomodoroBar.zip
ditto -x -k "$WORK/PomodoroBar.zip" "$WORK"
codesign --verify --deep --strict "$WORK/PomodoroBar.app"
mkdir -p "$DEST"
pkill -x PomodoroBar || true
rm -rf "$DEST/PomodoroBar.app"
ditto "$WORK/PomodoroBar.app" "$DEST/PomodoroBar.app"
rm -rf "$WORK"
open -n "$DEST/PomodoroBar.app"
```

`pkill` only stops a copy running in this account. If this replaces an existing PomodoroBar, warn them first that a running timer resets.

**Check:** `pgrep -x PomodoroBar` prints a number.

## 4. Finish

Tell them, briefly:

- A timer icon is now in the menu bar, near the clock. If the menu bar is crowded, it may be hidden behind the notch.
- macOS asks once whether PomodoroBar may send notifications. Click **Allow**: that's how they learn a focus round or break has ended.
- Shortcuts: ⇧⌘P starts or pauses, ⇧⌘L skips.
- Updates come from the menu: **Check for Updates…**. They don't need Claude Code for that. The app also looks once a day, and the item then reads **Update to x.y…**.
- To have it start at login, they can add it in System Settings ▸ General ▸ Login Items.

Then say: "✅ PomodoroBar is installed."
