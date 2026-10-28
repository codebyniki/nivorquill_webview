# Feature and platform guide

Nivorquill currently uses `webview_flutter` on Android and iOS. Its public
controller API provides application-level WebView tools. Platform
behavior should be tested on the OS and WebView versions your app supports.

| Feature | Current support | Notes |
| --- | --- | --- |
| Remote HTTPS and trusted local HTML | Android, iOS | HTTP requires policy opt-in and platform network configuration. |
| Navigation rules and guard | Android, iOS | Main-frame callbacks only; not a network firewall. |
| Progress, title, URL, history and errors | Android, iOS | Native callbacks do not identify every navigation uniquely. |
| JSON and Promise JavaScript | Android, iOS | Requires scripting enabled and JSON-serializable results. |
| CSS, text find, metadata and scrolling | Android, iOS | CSS can be blocked by CSP; text find depends on `window.find`. |
| Background color, zoom, scrollbars and overlays | Android, iOS | Native rendering and gesture behavior can differ by platform. |
| HTTP errors, auth, dialogs and permissions | Optional callbacks | HTTP errors can include subresources; permissions require OS setup and app trust decisions. |
| Console and scroll events | Optional callbacks | Console output may contain sensitive data; logging is opt-in. |
| Cookies | Shared native store | Clearing cookies affects other WebViews; platform URL requirements differ. |
| Navigation and error UI, retry | Optional widgets and controller method | Retry issues a new GET; local HTML is reloaded separately. |
| Other upstream features | Native controller / upstream APIs | Direct calls can bypass wrapper policy; preserve the navigation delegate. |
| Downloads, screenshots, PDF, headless views, in-app browser | Not implemented | Require additional platform APIs or a different backend. |
| Request interception, popups, content blockers, isolated profiles | Not implemented | Need platform-specific design and device tests. |
| Privileged JS-to-Dart handlers, document-start scripts | Not implemented | Require a separate security and lifecycle design. |
| macOS, Windows, web | Not supported | Upstream support does not imply wrapper support. |

For initialization, errors, lifecycle and policy caveats see the [README](../README.md).
For the migration mapping see [MIGRATING.md](MIGRATING.md). The roadmap prioritizes features that can be supported and tested on the
underlying native platforms.
