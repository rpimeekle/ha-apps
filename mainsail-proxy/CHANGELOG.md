# Changelog

## 1.0.1

- Webcam: entering the stream address as **Webcam URL** (for example `http://192.168.1.50:8080/stream` or `...?action=stream`) gave a 404 in the panel. The app now uses the camera streamer's base address instead and says so in the log.

## 1.0.0

- Initial release: Mainsail v2.19.0 in the Home Assistant sidebar through ingress.
- Proxies Moonraker's API and websocket to a configurable Moonraker server, with optional API key.
- Optional webcam proxy, start-up self-test and request logging.
