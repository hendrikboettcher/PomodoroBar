# PomodoroBar

A small Pomodoro timer for the macOS menu bar, with notifications, global shortcuts and statistics. English and German. It needs an Apple-chip Mac with macOS 13 or newer.

## Install

Paste this into [Claude Code](https://claude.com/claude-code):

> Install PomodoroBar on my Mac by following https://github.com/hendrikboettcher/PomodoroBar/blob/main/SETUP.md

Downloading the zip with a browser doesn't work: the app has no Apple Developer ID, so macOS refuses a browser-downloaded copy.

## Updates

Use **Check for Updates…** in the menu. The app also asks GitHub once a day whether there's a new release; that's the only network request it makes. Your statistics stay on your Mac in `~/Library/Application Support/PomodoroBar`.

## Development

You only need the Command Line Tools, not Xcode.

```bash
./build.sh
```

This builds the app and installs it to `/Applications`.

To publish a change, raise the number in `VERSION`, commit, and run:

```bash
./release.sh --publish
```

## License

[MIT](LICENSE)
