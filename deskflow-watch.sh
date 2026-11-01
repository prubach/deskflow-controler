#!/usr/bin/env bash
# Restarts Deskflow (Flatpak) when the monitor setup changes or the peer host appears.
# Works on Wayland and X11 by polling DRM sysfs (connector status + EDID) and pinging the peer.
set -u

APP_ID="org.deskflow.deskflow"
PEER="${PEER:-yoga}"
INTERVAL="${INTERVAL:-3}"     # seconds between checks
SETTLE="${SETTLE:-3}"         # wait for the change to settle before restarting
COOLDOWN="${COOLDOWN:-10}"    # minimum seconds between restarts

log() { echo "$(date '+%F %T') $*"; }

monitor_state() {
    local c
    for c in /sys/class/drm/card*-*; do
        [ -e "$c/status" ] || continue
        printf '%s %s %s\n' "$(basename "$c")" "$(cat "$c/status")" \
            "$(md5sum < "$c/edid" 2>/dev/null | cut -d' ' -f1)"
    done
}

peer_up() { ping -c1 -W1 "$PEER" >/dev/null 2>&1; }

restart_deskflow() {
    log "Restarting Deskflow: $1"
    flatpak kill "$APP_ID" 2>/dev/null
    sleep 1
    nohup flatpak run "$APP_ID" >/dev/null 2>&1 &
    last_restart=$(date +%s)
}

last_restart=0
prev_mon=$(monitor_state)
peer_up && prev_peer=1 || prev_peer=0
log "Watching monitors and peer '$PEER' (currently $([ $prev_peer = 1 ] && echo up || echo down))"

while sleep "$INTERVAL"; do
    reason=""

    cur_mon=$(monitor_state)
    if [ "$cur_mon" != "$prev_mon" ]; then
        sleep "$SETTLE"                  # let the display configuration settle
        cur_mon=$(monitor_state)
        prev_mon=$cur_mon
        reason="monitor setup changed"
    fi

    peer_up && cur_peer=1 || cur_peer=0
    if [ "$cur_peer" = 1 ] && [ "$prev_peer" = 0 ]; then
        reason="${reason:+$reason, }$PEER appeared on the network"
    fi
    prev_peer=$cur_peer

    if [ -n "$reason" ]; then
        if [ $(( $(date +%s) - last_restart )) -lt "$COOLDOWN" ]; then
            log "Change detected ($reason) but within cooldown, skipping"
        else
            restart_deskflow "$reason"
        fi
    fi
done
