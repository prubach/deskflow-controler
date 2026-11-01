I wrote `/home/pol/dev/priv/deskflow-controler/deskflow-watch.sh` and ran it for five seconds. It started and saw `yoga` as up. I did not trigger a restart, so the restart itself is untested.

**How it works**
- **Monitors:** every 3 seconds it checks the connector status and EDID of each display under `/sys/class/drm`. This works on Wayland, which is what you're running.
- **yoga:** it pings `yoga` and treats a down-to-up change as the machine appearing.
- **Restart:** on either event it runs `flatpak kill org.deskflow.deskflow` and then starts it again. After a monitor change it waits 3 seconds for the display configuration to settle. It also skips restarts that come within 10 seconds of the last one.

**Run it**
```
./deskflow-watch.sh
```
You can override the defaults with environment variables, e.g. `PEER=yoga.local INTERVAL=5 ./deskflow-watch.sh`.

Because `yoga` is detected by ping, it must resolve by that name from zalman. If it doesn't, set `PEER` to its hostname or IP.

To run it at login, add it to your session autostart or a systemd `--user` service. I can write the unit file if you want.



I wrote `deskflow-yoga-watch.sh` in the same folder. It passes a syntax check, but I haven't run it. It has to run on yoga, so copy it over.

**How it works**
- It checks every 3 seconds, via NetworkManager (`nmcli`), whether yoga is on the `Lupus` Wi-Fi.
- When yoga joins `Lupus`, it pings `zalman` for up to 30 seconds until it responds. It then stops and restarts Deskflow. It skips the restart if the last one was under 10 seconds ago.
- It uses the Flatpak (`org.deskflow.deskflow`) if that is installed on yoga. Otherwise it uses a native `deskflow` binary.

**Run it**
```
./deskflow-yoga-watch.sh
```
You can override the defaults with environment variables, e.g. `SSID=Lupus SERVER=zalman.local ./deskflow-yoga-watch.sh`.

- **Assumption:** I assumed yoga runs Linux with NetworkManager. If it's Windows or macOS, tell me and I'll adapt it.
- **Server name:** `zalman` must resolve from yoga. If it doesn't, set `SERVER` to its hostname or IP.