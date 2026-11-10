# Shutdown Timer

**Force shut down your Mac after a set time. No app can block it.**

A Raycast extension (and a plain shell script) that powers off your Mac when a countdown ends. It does not ask apps for permission, so an "unsaved changes" dialog or a stuck app cannot keep the machine on.

**English** | [Türkçe](README.tr.md)

---

## The problem

The built-in ways to schedule a shutdown are polite. They ask every open app to quit, and a single app with an unsaved document or a confirmation dialog cancels the whole thing. You come back hours later and the Mac is still on.

Shutdown Timer is not polite. When time is up it runs `shutdown -h now` as root. Apps are terminated, not asked. If the machine is somehow still up 60 seconds later, `halt -q` cuts it off.

> **Unsaved work is lost.** That is the point of the tool. A warning dialog appears 5 minutes and 1 minute before the shutdown, but nothing waits for you to answer it.

## Install

Requires macOS, [Raycast](https://www.raycast.com) and Node.js.

```bash
git clone https://github.com/merttopuz/shutdown-timer.git
cd shutdown-timer
npm install
npm run dev
```

`npm run dev` registers the extension in Raycast. You can stop it afterwards (`Ctrl+C`); the extension stays installed.

## Commands

| Command        | What it does                                                                                                       |
| -------------- | ------------------------------------------------------------------------------------------------------------------ |
| Start Timer    | Schedules the shutdown after the given number of minutes (120 if left empty). Asks for the administrator password. |
| Time Remaining | Shows the shutdown time and how long is left.                                                                      |
| Cancel Timer   | Removes the active timer. Asks for the administrator password.                                                     |

Starting a new timer replaces the active one.

## Without Raycast

The extension is a thin wrapper around one shell script, which works on its own:

```bash
assets/shutdown-timer.sh 90       # shut down in 90 minutes (asks for sudo)
assets/shutdown-timer.sh status   # time remaining
assets/shutdown-timer.sh cancel   # cancel the timer (asks for sudo)
```

## How it works

- **A root LaunchDaemon holds the countdown.** Quitting Raycast, closing the terminal, logging out or restarting does not stop it. The only way out is the cancel command.
- **Nothing at user level can interfere.** The running copy of the script is installed into a root-owned directory (`/Library/PrivilegedHelperTools`), so an app running as you cannot edit or kill it. If the process is killed anyway, launchd starts it again.
- **It watches the wall clock, not a sleep timer.** Time spent asleep counts. Idle sleep is blocked during the countdown and a wake is scheduled for the target time. If the lid is closed and the Mac stays asleep past the target, it shuts down as soon as it wakes.
- **No surprise shutdown at boot.** If the Mac was already turned off before the target and boots after it, the stale timer removes itself instead of firing.

## What it installs

Only while a timer is active:

```
/Library/LaunchDaemons/local.shutdown-timer.plist
/Library/PrivilegedHelperTools/local.shutdown-timer.sh
```

Both are removed when the timer fires or is cancelled. Nothing else is left on the system.

## License

[MIT](LICENSE)
