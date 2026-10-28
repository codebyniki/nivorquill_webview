import 'dart:async';
import 'dart:ui';

import 'package:webview_flutter/webview_flutter.dart';

import 'models.dart';

/// Backend contract used by a Nivorquill controller.
///
/// Implementations provide native WebView operations and report navigation
/// activity through [EngineCallbacks].
abstract interface class NivorquillEngine {
  /// Configures the backend with [settings] and installs [callbacks].
  Future<void> initialize(
    NivorquillSettings settings,
    EngineCallbacks callbacks,
  );

  /// Starts a GET request to [uri] with the initial request [headers].
  Future<void> load(Uri uri, Map<String, String> headers);

  /// Loads application-provided [html], optionally resolving URLs against [baseUrl].
  Future<void> loadHtml(String html, Uri? baseUrl);

  /// Reloads the current document.
  Future<void> reload();

  /// Navigates to the preceding history entry.
  Future<void> goBack();

  /// Navigates to the next history entry.
  Future<void> goForward();

  /// Returns whether a preceding history entry is available.
  Future<bool> canGoBack();

  /// Returns whether a subsequent history entry is available.
  Future<bool> canGoForward();

  /// Returns the current document title, if available.
  Future<String?> title();

  /// Returns the current document URL, if available.
  Future<String?> currentUrl();

  /// Executes JavaScript [source] without returning its value.
  Future<void> runJavaScript(String source);

  /// Evaluates JavaScript [source] and returns the native result.
  Future<Object> evaluate(String source);

  /// Moves to absolute native WebView coordinates [x], [y].
  Future<void> scrollTo(int x, int y);

  /// Moves by the relative native WebView offsets [x], [y].
  Future<void> scrollBy(int x, int y);

  /// Returns the current native WebView scroll position.
  Future<Offset> scrollPosition();

  /// Clears the WebView cache without clearing cookies.
  Future<void> clearCache();

  /// Clears native WebView local storage.
  Future<void> clearLocalStorage();
}

/// Callbacks a backend uses to report navigation and loading activity.
final class EngineCallbacks {
  /// Creates the callbacks required by a WebView backend.
  const EngineCallbacks({
    required this.started,
    required this.finished,
    required this.progress,
    required this.urlChanged,
    required this.failed,
    required this.httpError,
    required this.navigate,
  });

  /// Reports that a URL has started loading.
  final void Function(String) started;

  /// Reports that a URL has finished loading.
  final void Function(String) finished;

  /// Reports load progress as a percentage.
  final void Function(int) progress;

  /// Reports a change to the current URL.
  final void Function(String) urlChanged;

  /// Reports a main-page loading failure.
  final void Function(NivorquillFailure) failed;

  /// Reports an HTTP response error, which may concern a subresource.
  final void Function(HttpResponseError) httpError;

  /// Decides whether a URL may be navigated to; the boolean identifies a main-frame request.
  final FutureOr<bool> Function(String, bool) navigate;
}
