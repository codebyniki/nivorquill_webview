# Nivorquill WebView

**A Flutter WebView package for applications that need clear navigation rules,
observable state and useful page tools.**

`nivorquill_webview` · **0.1.0** · intended targets: **iOS and Android**

This package is built on Flutter's `webview_flutter`.
It provides its own application API while delegating WKWebView / Android WebView
maintenance to Flutter's native plugins. See [validation](doc/VALIDATION.md)
for the checks completed and platform-specific limitations.

For a complete guide to controllers, settings, callbacks and widgets, see the
[API guide](doc/API.md).

## What is implemented

| Capability | Behavior |
| --- | --- |
| Native view | WKWebView on iOS; system WebView on Android |
| Navigation rules | HTTPS by default, optional exact scheme/host/port allowlist |
| Async navigation guard | Denies navigation on callback errors or timeout |
| State | Progress, phase, title, URL, elapsed time, history and failure |
| JSON scripting | Objects, arrays, primitives and null with explicit JS errors |
| Promise evaluation | Timeout, navigation invalidation, 16-call concurrency cap |
| Page tools | CSS injection, next/previous text search, metadata, scroll |
| Local content | Application-supplied HTML with optional base URL |
| UI | Persistent native view with replaceable loading and error overlays |
| Personalization | Native background, zoom gestures and progress indicator styling |
| Diagnostics | Broadcast events; no telemetry or URLs sent to a service |
| Extension | Access to the underlying WebViewController for platform APIs |

## Requirements

- Flutter **3.41+**, Dart **3.11+**.
- iOS **13+** / Android **API 24+** as the initial native support floor.
- A compatible Xcode and Android toolchain for your Flutter release.
- Resolved native plugin versions can raise minimum SDK requirements; inspect
  and commit the **application's** lockfile after validating its dependency set.
- macOS is possible through the upstream engine, but is not a supported target
  of this initial package. Web, Windows and Linux are not implemented.

## Installation

Once version 0.1.0 is published on pub.dev, add it to your app:

```yaml
dependencies:
  nivorquill_webview: ^0.1.0
```

For local development, place the package beside your application and use:

```yaml
dependencies:
  nivorquill_webview:
    path: ../nivorquill_webview
```

Run `flutter pub get` in your application. Local path dependencies are useful
for development but should not be used in published packages.

## Minimal use

Create the controller once in `State.initState`, not during `build`:

```dart
final controller = NivorquillController(
  settings: NivorquillSettings(
    policy: NivorquillPolicy(
      allowedOrigins: {Uri.parse('https://your-domain.example')},
    ),
  ),
);

// In an awaited startup method with your application's error handling:
await controller.load(Uri.parse('https://your-domain.example/dashboard'));

// In build(), inside a parent with bounded dimensions:
NivorquillView(controller: controller);

// In State.dispose(), after this view is removed:
controller.dispose();
```

`load` completes when the native engine accepts the command. It does not wait
for the document to finish loading. Observe `state.phase` or the `finished`
event for that. The widget and `load` both safely share `initialize()`.
Keep one controller attached to one view, and catch returned Future errors.

## Page tools

```dart
final value = await controller.evaluateJson('({title: document.title})');
final result = await controller.evaluateAsyncJson(
  'Promise.resolve({answer: 42})',
  timeout: const Duration(seconds: 3),
);
await controller.injectCss('body { font-size: 18px; }');
final found = await controller.findText('invoice');
await controller.findText('invoice', backwards: true);
final metadata = await controller.pageMetadata();
await controller.scrollTo(0, 400);
await controller.scrollBy(0, 100);
final position = await controller.scrollPosition();
```

### Appearance and gestures

Configure native view options when creating the controller and style the
progress indicator on the widget:

```dart
final controller = NivorquillController(
  settings: NivorquillSettings(
    backgroundColor: const Color(0xFF101B2B),
    zoomEnabled: false,
    verticalScrollBarEnabled: false,
  ),
);

NivorquillView(
  controller: controller,
  progressColor: Colors.teal,
  progressBackgroundColor: Colors.black12,
  progressHeight: 3,
);
```

The color, zoom and scrollbar settings default to `null`, leaving the platform defaults
unchanged. Set `showProgress: false` to hide the indicator, or provide
`loadingBuilder` and `errorBuilder` for custom overlays. Scroll positions and
offsets use the native WebView coordinate system. Native behavior can differ
by platform; test the settings on your target devices. Explicit scrollbar settings
fail initialization with `UnsupportedError` if the platform does not support them.

Expressions are trusted app code. Pass variable data with `jsonEncode` rather
than concatenating raw user input. Results must be JSON serializable: cycles
and BigInt produce errors; normal JSON semantics apply to NaN and object fields
containing functions/undefined. Promises require `evaluateAsyncJson`.

Timeout stops waiting, not the page's JavaScript or network operation. Async
results temporarily use unpredictable page-global keys; this is not a trusted
execution world. A hostile page can inspect or modify its own environment.

`findText` uses the WebKit/Chromium `window.find` extension. It selects and wraps
through matches; it does not count all matches or guarantee PDF/iframe search.
Injected styles may be blocked by the page's Content Security Policy.

## State and events

Use `ListenableBuilder(listenable: controller, builder: ...)` and read
`controller.state` to build your toolbar. Subscribe to `controller.events` for
`started`, `finished`, `blocked`, `failure`, and `scriptFailure`; cancel your
subscription when the consumer is disposed. Events are not replayed.

Navigation guards may run more than once for a navigation; keep them idempotent.
Custom schemes such as `mailto:`, `tel:` and `intent:` are blocked. If you want
external launches, handle `onNavigationBlocked` or the `blocked` event with an
app-specific allowlist and the appropriate launcher. No external app is
launched implicitly.

## Run the example

```sh
cd example
flutter create --platforms=ios,android --project-name=nivorquill_example .
flutter pub get
flutter run
```

The example begins with local HTML. To open remote pages on Android, add
`<uses-permission android:name="android.permission.INTERNET" />` directly
under `<manifest>` in `android/app/src/main/AndroidManifest.xml`, including
for release builds. Keep HTTPS; do not globally disable ATS or Android's
cleartext protection. Verify native minimum deployment targets after generation.

Platform folders are generated by your installed Flutter version so you inherit
its current AppDelegate, Gradle and Xcode templates. Existing app migrations
are covered in [the iOS guide](doc/IOS_MIGRATION.md).

## Deliberate limits

This release focuses on composition and application-level lifecycle handling. No managed downloads, PDF/screenshot export, headless WebViews, full
request interception, content blockers, popup/tab management, incognito data
stores, document-start scripts, service worker interception, or privileged
JS-to-Dart RPC are implemented. File selection, media permissions, dialogs and
authentication need app-specific upstream platform configuration and testing.

Navigation policies inspect app-initiated loads and main-frame requests exposed
by the native delegate. They are **not a network sandbox**. Subresources,
fetch/XHR, iframes, redirects and history have platform-specific callback
coverage. Use CSP and server-side authorization; do not treat a URL allowlist
as authorization. The default policy permits all HTTPS origins until restricted.

Native callbacks lack navigation IDs. Clearly stale finish/error URLs are
filtered and Dart script results use generation checks, but rapid overlapping
same-URL loads cannot be perfectly distinguished. A timed-out page is marked
failed; native network activity is not automatically stopped. No automatic
retry is performed. HTTP 4xx/5xx documents render normally by default;
the error overlay handles reported main-frame transport errors and timeouts.

`loadHtml` is for trusted application content and bypasses origin rules for
the initial document. `reload()` requires a policy-allowed remote URL; reload
local HTML by calling `loadHtml` again. Cache/storage are shared by the native
engine; clearing them is not a per-view or incognito operation. Cookies remain
untouched. Native controller calls can bypass the wrapper's checks.

## Development and next steps

```sh
flutter pub get
dart format lib test example/lib example/integration_test
flutter analyze
flutter test
cd example
flutter test integration_test/webview_test.dart -d <device-id>
```

The included CI template checks Dart/Flutter code and compiles generated iOS and
Android example hosts. It has not been executed on a remote runner. See
[architecture and roadmap](doc/ARCHITECTURE.md), [integration guide](doc/MIGRATING.md)
and [validation status](doc/VALIDATION.md). The [feature and platform guide](doc/FEATURES.md)
lists supported features and current gaps.

## Callbacks, diagnostics and recovery

`NivorquillSettings` accepts optional `onHttpError`, `onConsoleMessage`,
`onScroll`, `onJavaScriptAlert`, `onJavaScriptConfirm`, `onJavaScriptPrompt`,
`onHttpAuth` and `onPermissionRequest` callbacks. They are installed when the
controller initializes; create a new controller to change them. Console logging
is opt-in and may expose page data. HTTP error callbacks may include resources
other than the main page; request and response details vary by platform. The
package renders HTTP error pages by default; opt in to the error overlay as
shown below.

Dialog callbacks return the result expected by the platform. Prompt callbacks
return a string; the upstream API does not expose a separate cancel result. The
HTTP authentication callback returns a `WebViewCredential` or null to cancel;
exceptions and interaction timeouts cancel the request. Permission callbacks return
true to grant all requested resources or false to deny, and default to denial.
The configurable `interactionTimeout` defaults to 60 seconds; permission
errors and timeouts deny the request.
App-level OS permission declarations and user consent are still required.
The generic permission request does not include a verified requesting origin;
only grant permissions when your application can establish trust. When supplying
a native controller, configure its permission handler at construction instead.

```dart
final cookies = NivorquillCookies();
await cookies.set(WebViewCookie(name: 'theme', value: 'dark', domain: 'example.com'));
final existing = await cookies.get(Uri.parse('https://example.com'));
// await cookies.clearAll(); // Clears the shared store for all WebViews.
```

Cookie URL requirements and available attributes differ by platform. Clearing
cookies affects all WebViews using the shared store; it does not clear local
storage or cache. Handle credentials and cookie values as sensitive data.

Use `NivorquillNavigationBar` for optional back, forward and reload controls,
and `NivorquillErrorPanel` in an `errorBuilder` for customizable offline/error
content. Its retry action is supplied by the app. `controller.retry()` makes a
new GET request to the last recorded allowed URL; it does not preserve custom
headers or resubmit a form. Retry is never automatic. For local HTML, call
`loadHtml` again. Device and network state detection remains the app's choice.

### Show a custom HTTP error page

```dart
final controller = NivorquillController(
  settings: NivorquillSettings(
    showHttpErrorPage: true, // Show the error overlay for HTTP 500–599.
    // Optional: choose different status codes.
    // httpErrorStatusCodes: (status) => status == 404 || status >= 500,
    onHttpError: (error) => debugPrint('HTTP ${error.response?.statusCode}'),
  ),
);

NivorquillView(
  controller: controller,
  httpErrorBuilder: (context, error) => NivorquillHtmlErrorPage(
    html: '''
      <!doctype html><html><body>
        <h1>We'll be back soon</h1>
        <p>Our server is temporarily unavailable.</p>
      </body></html>
    ''',
  ),
  errorBuilder: (context, error) => NivorquillErrorPanel(
    message: 'The page is temporarily unavailable.',
    onRetry: () async {
      try {
        await controller.retry();
      } catch (error) {
        debugPrint('Retry failed: $error');
      }
    },
  ),
);
```

`httpErrorBuilder` receives an HTTP failure and takes precedence over the
general `errorBuilder`. `NivorquillHtmlErrorPage` displays trusted app-supplied
HTML in a separate WebView with JavaScript disabled; you can instead return any
Flutter widget. HTML should be supplied by the app, not untrusted page content.

This is a best-effort overlay, not response interception. The platform callback
can arrive after rendering starts, so the server page may briefly appear. A
callback with a different known URL is ignored for the overlay. Some platform
callbacks omit the URL and frame information (including current iOS callbacks);
an error from another frame during loading can therefore be mistaken for the
main page. Conversely, a main-frame error may not be matched if URL reporting
lags a redirect. The original `onHttpError` callback still receives all reported
HTTP errors. Test your navigation and error scenarios on both platforms.
