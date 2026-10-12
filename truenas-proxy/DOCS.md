# TrueNAS UI

Opens your TrueNAS web interface inside Home Assistant, in the sidebar. The app
is a small proxy: TrueNAS itself is untouched, and you still sign in with your
TrueNAS account.

## Setup

1. Set **TrueNAS URL** to the address you normally use for the TrueNAS web
   interface, for example `https://192.168.1.20`. Add the port if you changed
   it (e.g. `https://192.168.1.20:8443`). Use the IP address: `.local` names
   usually don't resolve inside Home Assistant apps.
2. Leave **Verify certificate** off unless you installed a trusted certificate
   on TrueNAS. TrueNAS ships with a self-signed one.
3. Start the app and check the log:
   ```
   Self-test TrueNAS (https://192.168.1.20:443): OK
   Self-test panel: OK (base path and URL fix injected)
   ```
4. Open **TrueNAS** from the sidebar and sign in.

### If the self-test complains

- **REDIRECTED to https://...**: TrueNAS forces HTTPS. Change the URL to
  `https://`.
- **FORBIDDEN**: TrueNAS has a web interface allowlist (System → General
  Settings → GUI). Add your Home Assistant machine's IP, because every request
  from this app comes from there.
- **UNREACHABLE**: check the address and the HTTP/HTTPS port set in TrueNAS.

## How it works

The TrueNAS interface expects to live at the root of its own site. In the
panel it lives under a Home Assistant path, so the app:

- rewrites the page's base path, which keeps its pages and files inside the
  panel;
- adds a small script to the page that redirects the interface's own server
  connections (the live API connection, the shell, uploads and downloads) to
  the panel path instead of the root of your Home Assistant site;
- removes the headers that stop TrueNAS from being shown inside another page.

## Good to know

- **Admins only.** Only Home Assistant administrators see the panel, and
  TrueNAS still asks for its own login.
- **Shared site with Home Assistant.** Inside the panel, TrueNAS runs on your
  Home Assistant address, so its saved login lives alongside Home Assistant's
  own. Pages from other apps you open in Home Assistant can technically reach
  it, as they can Home Assistant's. Only install apps you trust, and log out of
  TrueNAS when you're done if that matters to you.
- **Links that open new tabs** to TrueNAS pages outside the main interface
  (such as the API documentation) open on your Home Assistant address and
  won't work there. Use the TrueNAS address directly for those.
- **Changing TrueNAS's web interface settings** (ports, certificate, HTTPS
  redirect) from inside the panel may drop the connection. Update this app's
  URL afterwards if the address changed.
- **Remote access** works wherever Home Assistant does (Nabu Casa, your reverse
  proxy) without exposing TrueNAS.
