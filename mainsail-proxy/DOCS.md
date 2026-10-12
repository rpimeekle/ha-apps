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

Under the panel, a camera address like `http://192.168.1.50:8080/` can't be
used directly (and is blocked outright if you open Home Assistant over HTTPS).
Instead:

1. Set **Webcam URL** to your camera streamer's base address, for example
   `http://192.168.1.50:8080/` for crowsnest/ustreamer.
2. In Mainsail → Settings → Webcams, set the URLs **without a leading slash**:
   - Stream: `webcam/?action=stream`
   - Snapshot: `webcam/?action=snapshot`

A leading slash (`/webcam/...`) points at the root of your Home Assistant site
and won't load in the panel. Without it, the same setting still works in the
Mainsail on your Klipper host, because both resolve to `webcam/` on whichever
site you're viewing.

## Options

| Option | Meaning |
|---|---|
| `moonraker_url` | Moonraker address (required). |
| `moonraker_api_key` | Optional API key sent with every request to Moonraker. |
| `webcam_url` | Optional camera streamer address, served in the panel at `webcam/`. |
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
