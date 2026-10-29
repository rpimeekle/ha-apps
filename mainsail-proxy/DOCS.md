# Mainsail

Runs the [Mainsail](https://docs.mainsail.xyz/) web interface for Klipper in
the Home Assistant sidebar. It connects to the Moonraker server you already
have, wherever it runs (a Pi, a VM, a TrueNAS app); Klipper and Moonraker are
not installed by this app.

## Setup

1. Set **Moonraker URL** to your Moonraker address, for example
   `http://192.168.1.50:7125`. Use the IP address: `.local` names usually
   don't resolve inside Home Assistant apps.
2. Start the app and check the log for the self-test:
   ```
   Self-test Moonraker (http://192.168.1.50:7125): OK, Klipper state: ready
   Self-test panel: OK (Mainsail paths follow the ingress prefix)
   ```
3. Open **Mainsail** from the sidebar.

### If the self-test says REFUSED

Moonraker only accepts clients it trusts, and every request from this app
comes from your **Home Assistant machine's IP**. Either:

- add that IP (or your LAN range) to `moonraker.conf` and restart Moonraker:
  ```ini
  [authorization]
  trusted_clients:
      192.168.1.0/24
  ```
- or set **Moonraker API key** in this app. Moonraker shows the key from a
  trusted machine at `http://<moonraker>:7125/access/api_key`.

## Webcam

Usually there's nothing to set up. The app reads your camera list from Moonraker
(the same list your local Mainsail uses) and routes the camera through the
panel. Your browser only ever talks to Home Assistant, so the camera works at
home and remotely (Nabu Casa, HTTPS) with the same settings as your local
Mainsail.

- **Camera with a full address** in Mainsail, such as
  `http://192.168.1.50:8080/?action=stream`: detected automatically when the
  app starts. To choose it yourself, set **Webcam URL** to the camera's base
  address, e.g. `http://192.168.1.50:8080/`. A pasted stream address
  (`.../stream` or `...?action=stream`) is trimmed to the base for you.
- **Camera with `/webcam/?action=stream`** (the crowsnest default): served by
  the web server on your Klipper machine, so the app uses
  `http://<moonraker host>/webcam/`. If Mainsail on that machine isn't on
  port 80, set **Webcam URL** to its address followed by `/webcam/`, e.g.
  `http://192.168.1.50:81/webcam/`. Keep the `/webcam/` on the end: without
  it the panel gets Mainsail's own page instead of the camera.

Check the log after starting the app:
```
Webcam: detected http://192.168.1.50:8080/ from Mainsail's webcam settings
Self-test webcam 'Ender cam': OK (shown through the panel via http://192.168.1.50:8080/)
```

Good to know:

- The camera address is read when the app starts. Restart the app after
  changing camera addresses in Mainsail.
- One camera address (host and port) is routed. Several cameras on the same
  streamer are fine; a camera on a different machine shows only at home.
- Home Assistant must be able to reach the camera's port. If the self-test says
  *unreachable*, check the streamer accepts connections from other machines.

## Options

| Option | Meaning |
|---|---|
| `moonraker_url` | Moonraker address (required). |
| `moonraker_api_key` | Optional API key sent with every request to Moonraker. |
| `webcam_url` | Optional. Leave empty to detect the camera from Mainsail's settings, or set the camera's base address, e.g. `http://<ip>:8080/`. |
| `log_requests` | One log line per request, for troubleshooting. |

## Good to know

- **Full printer control.** Anyone who can open this panel can move, heat and
  start the printer. Only Home Assistant administrators see the panel.
- **Settings are shared.** Mainsail keeps its settings (dashboard layout,
  presets, webcams) in Moonraker, so they're the same as in the Mainsail on
  your Klipper host.
- **Its own copy of Mainsail.** This app ships Mainsail v2.19.0. Moonraker's
  update manager updates the Mainsail on your Klipper host, not this one; this
  one updates with the app.
- **Remote access** works wherever Home Assistant does (Nabu Casa, your reverse
  proxy) with no extra ports.
