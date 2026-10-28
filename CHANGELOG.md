# Changelog

## Unreleased

- Added opt-in HTTP error, JavaScript console, scroll, JavaScript dialog,
  HTTP authentication and permission callbacks.
- Added shared cookie management, reusable navigation and error components,
  and explicit user-initiated retry for allowed remote URLs.
- Added documentation for callback, privacy, recovery and platform behavior.
- Fixed a view initialization notification during Flutter's build phase.

## 0.1.0-dev.1

- Added optional native background color and zoom configuration, progress
  indicator and scrollbar styling, relative scrolling and scroll-position reading.

Initial development source release. Not published and not device-validated.

- Native rendering through webview_flutter; no forked UIKit registration code.
- Exact-origin policies and asynchronous navigation guards with fail-closed timeouts.
- Observable page state, progress, errors, duration and history availability.
- JSON-safe synchronous and Promise-based JavaScript evaluation.
- Navigation invalidation and bounded asynchronous script concurrency.
- Local HTML, CSS injection, text search, metadata and scrolling.
- Loading/error overlays, sample app, unit tests, device smoke test and CI template.
- UIScene migration and integration documentation.

