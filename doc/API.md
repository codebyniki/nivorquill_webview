# Nivorquill WebView API guide

Nivorquill embeds the native Android or iOS WebView in a Flutter app. The
controller manages navigation, observable page state and page tools; the view
renders the WebView and optional overlays. Import the public API with:

```dart
import 'package:nivorquill_webview/nivorquill_webview.dart';
```

## Set up a screen

Create one controller for each view and keep it for the screen's lifetime. The
following screen loads an HTTPS URL, displays progress and shows an error:

```dart
import 'package:flutter/material.dart';
import 'package:nivorquill_webview/nivorquill_webview.dart';

class WebScreen extends StatefulWidget {
  const WebScreen({super.key});

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late final NivorquillController controller;

  @override
  void initState() {
    super.initState();
    controller = NivorquillController(
      settings: NivorquillSettings(
        policy: NivorquillPolicy(
          allowedOrigins: {Uri.parse('https://example.com')},
        ),
        showHttpErrorPage: true,
      ),
    );
    _openPage();
  }

  Future<void> _openPage() async {
    try {
      await controller.load(Uri.parse('https://example.com'));
    } catch (error) {
      debugPrint('Could not open page: $error');
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Web page')),
    body: NivorquillView(
      controller: controller,
      errorBuilder: (context, error) => NivorquillErrorPanel(
        message: 'Unable to load the page.',
        onRetry: () async {
          try {
            await controller.retry();
          } catch (error) {
            debugPrint('Retry failed: $error');
          }
        },
      ),
    ),
  );
}
```

`load` completes when the native engine accepts the request, not when the page
finishes loading. Handle its returned future and observe the controller's state
or `finished` event for the page result. Keep the view in a bounded layout;
inside a `Column`, use `Expanded`. `NivorquillView` initializes its controller
if necessary. `initialize()` can also be awaited explicitly. The controller is
owned by the caller and should be disposed when the screen is removed.

## Navigation and policy

| Operation | Result |
| --- | --- |
| `load(uri, headers: ...)` | Starts a remote HTTP(S) GET subject to the policy and guard. Headers apply to the initial request, not necessarily redirects or subresources. |
| `loadHtml(html, baseUrl: ...)` | Loads trusted application HTML. The initial document bypasses remote origin rules; an optional base URL must pass the policy. |
| `reload()` | Reloads a policy-allowed remote URL. Load local HTML again with `loadHtml`. |
| `retry()` | Starts a new GET for the last recorded allowed remote URL. It does not preserve headers or resubmit forms. |
| `goBack()` / `goForward()` | Return `true` when a history action was available and issued, or `false` when unavailable. |

By default `NivorquillPolicy` permits HTTPS and blocks other schemes. Set
`allowedOrigins` to exact HTTP(S) origins, including a non-default port if
needed. `null` allows any permitted origin; an empty set blocks remote origins.
`allowHttp: true` permits HTTP at the policy level, but your platform network
configuration may still block it. An optional `navigationGuard` can make an
additional asynchronous decision. It may run more than once; make it
idempotent. Errors and timeouts deny navigation.

These rules cover app-initiated requests and native main-frame navigation
callbacks. They are not a network firewall and do not reliably control all
redirects, frames, fetches or subresources. Enforce access on the server and
use a content security policy appropriate for your content.

## Observe state and events

The controller is a `ChangeNotifier`. Use `ListenableBuilder` to read
`controller.state`: `phase`, `uri`, `title`, `progress` (0–100),
`canGoBack`, `canGoForward`, `elapsed`, `failure`, and `isLoading`. Phases
are `idle`, `initializing`, `loading`, `ready` and `failed`.

`controller.events` is a broadcast stream of `started`, `finished`, `blocked`,
`failure` and `scriptFailure` events. Each event has a timestamp and may have
a URI or failure. Events are not replayed. Cancel subscriptions when the
consumer is disposed. `NivorquillFailure` provides `code`, `message`, and an
optional `uri`; failures can also be returned through a method's future.
Native callbacks do not provide navigation IDs, so overlapping same-URL loads
cannot always be distinguished.

## Configure the controller

Pass `NivorquillSettings` when constructing a controller. Settings are applied
at initialization; create a new controller to change them.

| Setting | Default and purpose |
| --- | --- |
| `policy` | HTTPS policy described above. |
| `javaScriptEnabled` | `true`; set `false` to disable scripting. |
| `userAgent` | `null` keeps the platform default. |
| `backgroundColor`, `zoomEnabled` | `null` keeps the platform default. |
| `verticalScrollBarEnabled`, `horizontalScrollBarEnabled` | `null` keeps the platform default. An explicit setting fails initialization if unsupported. |
| `navigationTimeout` | 30 seconds before a load is marked failed; native network activity is not stopped. |
| `guardTimeout` | 5 seconds for the navigation guard. |
| `interactionTimeout` | 60 seconds for HTTP authentication and permission decisions. |
| `scriptTimeout` | 5 seconds for script operations unless overridden. |
| `pageFinishedScripts` | Trusted scripts run sequentially after page finish, not at document start. Requires JavaScript. |
| `showHttpErrorPage` | `false`; when enabled, reported HTTP 500–599 errors can show the error overlay. |
| `httpErrorStatusCodes` | Optional predicate to choose HTTP statuses instead of the default 500–599. |

Timeouts must be positive. HTTP error overlays are best effort: native callbacks
may omit URL or frame information, arrive after rendering begins, or report a
resource rather than the main page. A known URL different from the current page
is ignored for the overlay. See the [HTTP error example](../README.md#show-a-custom-http-error-page).

## Callbacks

All callbacks below are optional settings. Install them before initialization.

| Callback | Use |
| --- | --- |
| `onHttpError` | Observe reported HTTP errors, including possible subresources. |
| `onNavigationBlocked` | Observe denied URLs and choose whether to handle external links in the app. |
| `onConsoleMessage` | Observe JavaScript console messages. Opt in only when appropriate; messages can contain sensitive information. |
| `onScroll` | Receive a native scroll position as an `Offset`. |
| `onJavaScriptAlert` | Handle an alert and complete the returned future. |
| `onJavaScriptConfirm` | Return `true` to confirm or `false` to cancel. |
| `onJavaScriptPrompt` | Return a string; the underlying API has no separate cancel result. |
| `onHttpAuth` | Return `WebViewCredential`, or `null` to cancel. Errors and timeouts cancel. |
| `onPermissionRequest` | Return `true` to grant all requested resources or `false` to deny. Errors and timeouts deny. |

Permission requests are denied by default for a controller created by
Nivorquill. Platform permission declarations and user consent are still needed.
The generic request does not supply a verified origin; grant only when the app
can establish trust. If supplying a `nativeController`, configure its
permission handler at construction and do not also set `onPermissionRequest`.

## JavaScript and page tools

```dart
final title = await controller.evaluateJson('document.title');
final result = await controller.evaluateAsyncJson(
  'Promise.resolve({answer: 42})',
  timeout: const Duration(seconds: 3),
);
await controller.injectCss('body { font-size: 18px; }');
final found = await controller.findText('invoice');
final metadata = await controller.pageMetadata();
await controller.scrollTo(0, 400);
await controller.scrollBy(0, 100);
final position = await controller.scrollPosition();
```

Script expressions are trusted app code and results must be JSON serializable.
Encode variable data with `jsonEncode`; don't concatenate untrusted input into
source. Async evaluation supports up to 16 concurrent calls. Navigation
invalidates pending results. Timeout stops waiting, not the JavaScript or its
network activity. CSS can be blocked by the page's content security policy.
Text search uses `window.find`, selects and wraps matches, and does not provide
a total count or guarantee PDF or iframe search. Scroll values use native
WebView coordinates.

## View and reusable widgets

`NivorquillView` accepts `showProgress`, `progressColor`,
`progressBackgroundColor`, `progressHeight`, `loadingBuilder`, `errorBuilder`
and `gestureRecognizers`. `httpErrorBuilder` specifically handles HTTP
failures and takes precedence over `errorBuilder`. Use
`NivorquillHtmlErrorPage` to display trusted application HTML with JavaScript
disabled, or return your own Flutter widget. The native view remains mounted
under its overlays.
`NivorquillNavigationBar` provides back, forward and reload controls and an
optional `onError` callback. `NivorquillErrorPanel` provides customizable
content and an optional user-triggered retry button; it does not detect network
connectivity or retry automatically.

## Cookies, storage and platform access

`NivorquillCookies().set(cookie)`, `.get(uri)` and `.clearAll()` use the native
shared cookie store. Clearing affects other WebViews. `clearCache()` and
`clearLocalStorage()` are separate controller operations; neither clears
cookies. Storage and cache are not private per view.

`nativeController` exposes the underlying `WebViewController` for platform
APIs. Direct calls can bypass Nivorquill policy and lifecycle checks. Do not
replace its navigation delegate: Nivorquill relies on it for state and policy.
For device setup and platform limitations, see the [README](../README.md) and
[feature guide](FEATURES.md).
