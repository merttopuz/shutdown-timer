#!/bin/bash
# shutdown-timer: force shuts down this Mac after a given number of minutes.
#
# Usage:
#   shutdown-timer.sh [minutes]   Start the timer (default: 120 minutes)
#   shutdown-timer.sh status      Show the remaining time
#   shutdown-timer.sh cancel      Cancel the timer
#
# How it works:
#   - Installs a LaunchDaemon that runs as root. The countdown survives closing
#     the terminal, logging out and even a restart.
#   - When time is up it runs "shutdown -h now". That path does not ask apps,
#     so "unsaved changes" dialogs cannot block the shutdown.
#   - If the machine is still up after 60 seconds, "halt -q" cuts it off.
#   - Idle sleep is blocked during the countdown and a wake is scheduled for
#     the target time. If time runs out during sleep, it shuts down on wake.
#   - The running copy lives in a root-owned directory, so no user-level app
#     can modify or stop it.

set -u
PATH=/usr/bin:/bin:/usr/sbin:/sbin

LABEL="local.shutdown-timer"
PLIST="/Library/LaunchDaemons/$LABEL.plist"
HELPER="/Library/PrivilegedHelperTools/$LABEL.sh"
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

die() {
  echo "Error: $*" >&2
  exit 1
}

usage() {
  sed -n '2,7p' "$SELF" | sed 's/^# \{0,1\}//'
}

need_root() {
  [ "$(id -u)" -eq 0 ] || exec sudo "$SELF" "$@"
}

read_target() {
  local t
  [ -f "$PLIST" ] || return 0
  t="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:3' "$PLIST" 2>/dev/null)"
  case "$t" in
    '' | *[!0-9]*) return 0 ;;
  esac
  echo "$t"
}

# Wake time, one minute before the target (in pmset format).
wake_date() {
  date -r "$(( $1 - 60 ))" '+%m/%d/%y %H:%M:%S'
}

remove_timer() {
  local target
  target="$(read_target)"
  launchctl bootout "system/$LABEL" 2>/dev/null
  if [ -n "$target" ]; then
    pmset schedule cancel wake "$(wake_date "$target")" 2>/dev/null
  fi
  rm -f "$PLIST" "$HELPER"
}

start() {
  local minutes="${1:-120}" target
  case "$minutes" in
    '' | *[!0-9]*) die "Duration must be a number of minutes (example: 120)" ;;
  esac
  minutes=$(( 10#$minutes ))
  [ "$minutes" -ge 1 ] || die "Duration must be at least 1 minute"
  need_root "$minutes"

  remove_timer
  target=$(( $(date +%s) + minutes * 60 ))

  [ -d "$(dirname "$HELPER")" ] || install -d -o root -g wheel -m 755 "$(dirname "$HELPER")"
  install -o root -g wheel -m 755 "$SELF" "$HELPER" || die "Could not install the helper script"

  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$HELPER</string>
    <string>_worker</string>
    <string>$target</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
</dict>
</plist>
EOF
  chown root:wheel "$PLIST"
  chmod 644 "$PLIST"

  if ! launchctl bootstrap system "$PLIST"; then
    rm -f "$PLIST" "$HELPER"
    die "Could not load the LaunchDaemon"
  fi

  if [ "$minutes" -gt 2 ]; then
    pmset schedule wake "$(wake_date "$target")" 2>/dev/null
  fi

  echo "Timer set: this Mac will force shut down at $(date -r "$target" '+%H:%M') (in $minutes minutes)."
  echo "Status: $SELF status"
  echo "Cancel: $SELF cancel"
}

stop() {
  if [ -z "$(read_target)" ]; then
    echo "No active timer."
    return
  fi
  need_root cancel
  remove_timer
  echo "Timer cancelled."
}

status() {
  local target left
  target="$(read_target)"
  if [ -z "$target" ]; then
    echo "No active timer."
    return
  fi
  if ! launchctl print "system/$LABEL" >/dev/null 2>&1; then
    echo "Warning: a timer is recorded but the service is not loaded. Start it again: $SELF <minutes>"
    return
  fi
  left=$(( target - $(date +%s) ))
  [ "$left" -lt 0 ] && left=0
  echo "Active: shutting down at $(date -r "$target" '+%H:%M') ($(( left / 60 )) min $(( left % 60 )) sec left)."
}

# Shows a warning dialog to the logged-in user. Runs in the background, so a
# dialog that fails to open or stays open never delays the shutdown.
warn() {
  local uid
  uid="$(stat -f %u /dev/console 2>/dev/null)" || return 0
  [ "${uid:-0}" -gt 0 ] 2>/dev/null || return 0
  launchctl asuser "$uid" sudo -u "#$uid" osascript -e \
    "display dialog \"This Mac will force shut down in $1. Save any unsaved work now.\" with title \"Shutdown Timer\" buttons {\"OK\"} default button 1 with icon caution giving up after 30" \
    >/dev/null 2>&1 &
}

# Run as root by the LaunchDaemon.
worker() {
  local target="${1:-}" boot left warned=0
  case "$target" in
    '' | *[!0-9]*) exit 0 ;;
  esac

  # If the machine booted after the target, the job is stale (it already went
  # down): do not shut down again at boot, clean up and exit.
  boot="$(sysctl -n kern.boottime | sed -E 's/^\{ sec = ([0-9]+).*/\1/')"
  if [ "${boot:-0}" -ge "$target" ] 2>/dev/null; then
    rm -f "$PLIST" "$HELPER"
    exit 0
  fi

  # Block idle sleep during the countdown.
  caffeinate -is -w $$ &

  # Check the wall clock instead of "sleep 7200": time spent asleep counts too.
  while :; do
    left=$(( target - $(date +%s) ))
    [ "$left" -le 0 ] && break
    if [ "$left" -le 60 ] && [ "$warned" -lt 2 ]; then
      warn "1 minute"
      warned=2
    elif [ "$left" -le 300 ] && [ "$warned" -lt 1 ]; then
      warn "5 minutes"
      warned=1
    fi
    sleep 5
  done

  # Remove the record first so it does not fire again on the next boot.
  rm -f "$PLIST" "$HELPER"
  /sbin/shutdown -h now
  sleep 60
  /sbin/halt -q
}

main() {
  case "${1:-}" in
    _worker) worker "${2:-}" ;;
    cancel) stop ;;
    status) status ;;
    -h | --help | help) usage ;;
    *) start "$@" ;;
  esac
}

main "$@"
exit 0
