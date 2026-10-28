import 'dart:async';
import 'dart:ui';

import 'models.dart';

/// Small adapter boundary, also used by deterministic unit tests.
abstract interface class NivorquillEngine {
  Future<void> initialize(
    NivorquillSettings settings,
    EngineCallbacks callbacks,
  );
  Future<void> load(Uri uri, Map<String, String> headers);
  Future<void> loadHtml(String html, Uri? baseUrl);
  Future<void> reload();
  Future<void> goBack();
  Future<void> goForward();
  Future<bool> canGoBack();
  Future<bool> canGoForward();
  Future<String?> title();
  Future<String?> currentUrl();
  Future<void> runJavaScript(String source);
  Future<Object> evaluate(String source);
  Future<void> scrollTo(int x, int y);
  Future<void> scrollBy(int x, int y);
  Future<Offset> scrollPosition();
  Future<void> clearCache();
  Future<void> clearLocalStorage();
}

final class EngineCallbacks {
  const EngineCallbacks({
    required this.started,
    required this.finished,
    required this.progress,
    required this.urlChanged,
    required this.failed,
    required this.navigate,
  });
  final void Function(String) started;
  final void Function(String) finished;
  final void Function(int) progress;
  final void Function(String) urlChanged;
  final void Function(NivorquillFailure) failed;
  final FutureOr<bool> Function(String, bool) navigate;
}
