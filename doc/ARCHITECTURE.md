# Architecture and delivery

## Drivers

1. Reduce native migration work by reusing Flutter-maintained platform adapters.
2. Make the application's navigation and state behavior explicit and testable.
3. Keep dependency and operating costs low: no backend, subscription or telemetry.
4. Preserve access to platform capabilities without duplicating native internals.
5. State security and compatibility limits precisely rather than promising parity.

## Stack and boundaries

The Flutter widget observes a ChangeNotifier controller. The controller owns
policy, state, asynchronous sequencing and page tools. An engine adapter calls
`webview_flutter`, which delegates to `webview_flutter_wkwebview` on iOS and
`webview_flutter_android` on Android. A fake engine isolates controller tests.

Flow: validate an app navigation, await the optional guard, issue a native
request, receive native callbacks, update state and notify the view. The widget
keeps the native view alive while updating its overlays. Page-finished scripts
run sequentially, with errors reported as scriptFailure events.

The page is an untrusted execution environment. The wrapper exposes no
privileged JavaScript-to-native handler. JSON encoding protects data insertion
but does not make caller-supplied JavaScript source safe. TLS and origin security
are left enabled. User content and credentials never leave the device through
this package. Applications own their network authentication and privacy policy.

## Why this architecture

A new Swift/Kotlin plugin would give maximum control but also
require reimplementing navigation, file input, dialogs, permissions, accessibility,
embedding and lifecycle behavior. This wrapper offers a smaller maintenance
surface while preserving a route to platform-specific extensions later.

The recurring cost is engineering/device testing across Flutter, OS and native
WebView updates, not hosted infrastructure. Application web content has its own
traffic and hosting costs; no cost estimates are invented here.

## Delivery sequence

1. Current source: controller, policy, page tools, adapter, view and regression tests.
2. Release gate: run analyzer/unit tests, native builds and device smoke tests;
   reproduce and fix the user's exact iOS failure with their host application.
3. Expand tests for authentication, redirects, background/foreground, keyboard,
   accessibility, file uploads, gesture composition and process termination.
4. Add features based on actual app needs, with platform support tables.

## Triggers for a native extension

- A required capability cannot be implemented using the upstream public API:
  add a small federated platform extension, with a real-device regression test.
- App requirements include privileged JS-to-Dart handlers: first implement
  native origin/frame provenance, navigation cancellation and per-handler schemas.
- Product requirements include private profiles, PDF/export, download management
  or document-start scripting: design platform adapters before promising parity.

No automatic retries, backend services, secrets, analytics or release publishing
are configured. The supplied CI template runs on pushes/PRs after this source is
placed in a GitHub repository; it does not create a repository or deploy anything.
