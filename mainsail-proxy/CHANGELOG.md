# Changelog

## 1.1.0

- The webcam now works in the panel with the same settings as your local Mainsail, at home and remotely: cameras with a full address (such as `http://<ip>:8080/?action=stream`) are routed through Home Assistant instead of being loaded directly by the browser.
- Webcams set up with the standard `/webcam/?action=stream` address also work in the panel.
- The camera address is detected from Mainsail's webcam settings, so `webcam_url` is now optional. Cameras using `/webcam/` are served from the Moonraker host's web server.
- The start-up self-test checks each camera set up in Mainsail and says how to fix any that won't show in the panel.
- Camera requests now fail with a clear message when no camera address is set or detected.

## 1.0.1

- Webcam: entering the stream address as **Webcam URL** (for example `http://192.168.1.50:8080/stream` or `...?action=stream`) gave a 404 in the panel. The app now uses the camera streamer's base address instead and says so in the log.

## 1.0.0

- Initial release: Mainsail v2.19.0 in the Home Assistant sidebar through ingress.
- Proxies Moonraker's API and websocket to a configurable Moonraker server, with optional API key.
- Optional webcam proxy, start-up self-test and request logging.
