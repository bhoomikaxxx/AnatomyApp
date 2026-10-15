#!/bin/bash
#
# install-when-awake.sh — install a built .app onto an Apple Vision Pro the
# moment it comes back online.
#
# Why: the Vision Pro drops its developer tunnel the instant it sleeps, so a
# one-shot `devicectl device install` fails more often than it succeeds, and the
# FIRST transfer after a reconnect often dies mid-stream. This polls devicectl's
# JSON tunnelState (connected|disconnected = reachable), installs, and retries.
#
# Usage:
#   scripts/install-when-awake.sh [--app <path>] [--device <udid>] [--minutes <n>]
#
# Defaults: the device build at /tmp/anatomy-dd-device (auto-generated scheme Run config = Debug),
# the first paired physical Vision Pro, 60 minutes.
#
set -uo pipefail

APP="/tmp/anatomy-dd-device/Build/Products/Debug-xros/AnatomyApp.app"
DEVICE=""
MINUTES=60

while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --minutes) MINUTES="$2"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ ! -d "$APP" ]; then
  echo "no app bundle at $APP — build it first (see CLAUDE.md)" >&2
  exit 1
fi
BUNDLE=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")

# Prints "<udid> <tunnelState>" for the device matching $1 (CoreDevice id or
# hardware UDID), or for the first physical Vision Pro when $1 is empty.
device_state() {
  local json; json=$(mktemp)
  xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1
  python3 - "$json" "${1:-}" <<'PYEOF'
import json, sys
want = sys.argv[2]
try:
    devs = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    sys.exit(0)
for d in devs:
    hp, cp = d.get("hardwareProperties", {}), d.get("connectionProperties", {})
    if hp.get("reality") == "virtual" or cp.get("transportType") == "sameMachine":
        continue
    ids = {d.get("identifier", ""), hp.get("udid", "")}
    if (want and want in ids) or (not want and "Reality" in hp.get("productType", "")):
        print(hp.get("udid") or d.get("identifier"), cp.get("tunnelState", "unknown"))
        break
PYEOF
  rm -f "$json"
}

if [ -z "$DEVICE" ]; then
  DEVICE=$(device_state "" | awk '{print $1}')
fi
if [ -z "$DEVICE" ]; then
  echo "no Vision Pro found — pair it from the HEADSET: Settings > General > Remote Devices" >&2
  exit 1
fi

echo "waiting up to ${MINUTES} min for $DEVICE to come online…"
echo "  (put the headset on and keep it awake; it installs by itself)"
DEADLINE=$(( $(date +%s) + MINUTES * 60 ))

while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  STATE=$(device_state "$DEVICE" | awk '{print $2}')
  # "disconnected" = reachable with the tunnel idle (devicectl opens it on
  # install); only "unavailable"/empty means the device can't be reached.
  if [ "$STATE" = "connected" ] || [ "$STATE" = "disconnected" ]; then
    echo "$(date +%T) reachable — installing"
    if xcrun devicectl device install app --device "$DEVICE" "$APP" --timeout 1800 >/tmp/anatomy-install.log 2>&1; then
      echo "$(date +%T) INSTALLED $(basename "$APP") ($BUNDLE)"
      xcrun devicectl device info apps --device "$DEVICE" --bundle-id "$BUNDLE" 2>/dev/null | tail -1
      exit 0
    fi
    echo "$(date +%T) transfer failed (normal on the first try) — retrying"
    tail -2 /tmp/anatomy-install.log | sed 's/^/    /'
  fi
  sleep 12
done

echo "gave up after ${MINUTES} min — the headset never came online"
exit 1
