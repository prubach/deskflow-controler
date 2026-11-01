#!/usr/bin/env bash
# Runs on yoga (Linux + NetworkManager). Starts/restarts Deskflow when yoga
# joins the Wi-Fi network SSID, so it (re)connects to the server (zalman).
set -u

SSID="${SSID:-Lupus}"
APP_ID="org.deskflow.deskflow"
SERVER="${SERVER:-zalman}"
INTERVAL="${INTERVAL:-3}"     # seconds between checks
SETTLE="${SETTLE:-5}"         # wait after joining for network/DNS to come up
COOLDOWN="${COOLDOWN:-10}"    # minimum seconds between restarts
APP_LOG="${APP_LOG:-/tmp/deskflow-app.log}"

log() { echo "$(date '+%F %T') $*"; }

current_ssid() { nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | sed -n 's/^yes://p' | head -n1; }

# The session exports QT_QPA_PLATFORM=xcb, which the Flatpak sandbox can't use
# (Deskflow then exits immediately); let Qt pick the platform itself.
unset QT_QPA_PLATFORM

# Use the Flatpak if installed, otherwise a native deskflow binary.
if flatpak info "$APP_ID" >/dev/null 2>&1; then
    stop_app()   { flatpak kill "$APP_ID" 2>/dev/null; }
    is_running() { flatpak ps --columns=application 2>/dev/null | grep -qx "$APP_ID"; }
    start_app()  { setsid -f flatpak run "$APP_ID" >>"$APP_LOG" 2>&1 </dev/null; }
else
    stop_app()   { pkill -x deskflow 2>/dev/null; }
    is_running() { pgrep -x deskflow >/dev/null 2>&1; }
    start_app()  { setsid -f deskflow >>"$APP_LOG" 2>&1 </dev/null; }
fi

restart_deskflow() {
    log "Restarting Deskflow: $1"
    stop_app
    # Wait (up to ~10 s) for the old instance to fully exit before starting.
    for _ in $(seq 1 20); do is_running || break; sleep 0.5; done
    is_running && { log "Old instance still running, forcing kill"; stop_app; sleep 2; }
    for attempt in 1 2 3; do
        start_app
        sleep 3
        if is_running; then log "Deskflow started"; break; fi
        log "Deskflow not running after start (attempt $attempt), see $APP_LOG"
    done
    last_restart=$(date +%s)
}

last_restart=0
prev_on=0
log "Watching for Wi-Fi '$SSID' (server: $SERVER)"

while true; do
    [ "$(current_ssid)" = "$SSID" ] && cur_on=1 || cur_on=0

    if [ "$cur_on" = 1 ] && [ "$prev_on" = 0 ]; then
        # Joined the network: wait until the server is reachable (up to SETTLE*6 s).
        for _ in $(seq 1 6); do
            ping -c1 -W1 "$SERVER" >/dev/null 2>&1 && break
            sleep "$SETTLE"
        done
        if [ $(( $(date +%s) - last_restart )) -lt "$COOLDOWN" ]; then
            log "Joined '$SSID' but within cooldown, skipping"
        else
            restart_deskflow "connected to '$SSID'"
        fi
    elif [ "$cur_on" = 0 ] && [ "$prev_on" = 1 ]; then
        log "Left '$SSID'"
    fi

    prev_on=$cur_on
    sleep "$INTERVAL"
done
