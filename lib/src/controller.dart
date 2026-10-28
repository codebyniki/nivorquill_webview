import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'engine.dart';
import 'flutter_engine.dart';
import 'models.dart';
import 'scripts.dart';

/// Own one controller per view. Call initialize before displaying the view,
/// and dispose it after removing that view from the widget tree.
final class NivorquillController extends ChangeNotifier {
  factory NivorquillController({
    NivorquillSettings? settings,
    NivorquillNavigationGuard? navigationGuard,
    WebViewController? nativeController,
  }) => NivorquillController.withEngine(
    FlutterWebEngine(
      _permissionCompatibleController(nativeController, settings) ??
          WebViewController(
            onPermissionRequest: (request) async {
              try {
                final allowed =
                    await (settings?.onPermissionRequest?.call(request) ??
                            Future.value(false))
                        .timeout(
                          settings?.interactionTimeout ??
                              const Duration(seconds: 60),
                        );
                if (allowed) {
                  await request.grant();
                } else {
                  await request.deny();
                }
              } catch (_) {
                await request.deny();
              }
            },
          ),
    ),
    settings: settings,
    navigationGuard: navigationGuard,
  );

  static WebViewController? _permissionCompatibleController(
    WebViewController? controller,
    NivorquillSettings? settings,
  ) {
    if (controller != null && settings?.onPermissionRequest != null) {
      throw ArgumentError(
        'Configure permission handling on the supplied native controller',
      );
    }
    return controller;
  }

  @visibleForTesting
  NivorquillController.withEngine(
    this._engine, {
    NivorquillSettings? settings,
    this.navigationGuard,
  }) : settings = settings ?? NivorquillSettings();

  final NivorquillEngine _engine;
  final NivorquillSettings settings;
  final NivorquillNavigationGuard? navigationGuard;
  final _events = StreamController<NivorquillEvent>.broadcast();
  NivorquillState _state = const NivorquillState();
  Future<void>? _initialization;
  Timer? _loadTimer;
  Stopwatch? _loadWatch;
  bool _disposed = false;
  bool _initialized = false;
  bool _localHtmlMode = false;
  int _generation = 0;
  int _request = 0;
  int _metadataRequest = 0;
  int _activeScripts = 0;

  NivorquillState get state => _state;
  Stream<NivorquillEvent> get events => _events.stream;
  bool get isInitialized => _initialized && !_disposed;

  /// Escape hatch for platform features. Direct native calls bypass policy
  /// and lifecycle checks. Do not replace the installed navigation delegate.
  WebViewController get nativeController {
    _ensureAlive();
    final engine = _engine;
    if (engine is FlutterWebEngine) {
      return engine.controller;
    }
    throw StateError('This test engine has no native controller');
  }

  Future<void> initialize() {
    _ensureAlive();
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    _set(_state.copyWith(phase: NivorquillPhase.initializing));
    try {
      await _engine.initialize(
        settings,
        EngineCallbacks(
          started: _started,
          finished: (url) {
            unawaited(_finished(url));
          },
          progress: (progress) {
            if (_state.isLoading) {
              _set(_state.copyWith(progress: progress.clamp(0, 100).toInt()));
            }
          },
          urlChanged: (url) {
            if (_disposed) {
              return;
            }
            _set(_state.copyWith(uri: Uri.tryParse(url)));
            unawaited(_refreshMetadata(_generation));
          },
          failed: _fail,
          navigate: (url, mainFrame) async {
            if (_disposed) {
              return false;
            }
            // The native callback is not a subresource firewall.
            if (!mainFrame) {
              return true;
            }
            // WKWebView may ask about its generated blank HTML document.
            // Remote pages cannot opt into this exception through load().
            if (_localHtmlMode && url == 'about:blank') {
              return true;
            }
            final uri = Uri.tryParse(url);
            final request = _request;
            final generation = _generation;
            final allowed = uri != null && await _allow(uri);
            return allowed &&
                !_disposed &&
                request == _request &&
                generation == _generation;
          },
        ),
      );
      _ensureAlive();
      _initialized = true;
      _set(_state.copyWith(phase: NivorquillPhase.idle));
    } catch (error) {
      _fail(NivorquillFailure('initialization', error.toString()));
      rethrow;
    }
  }

  /// Loads an HTTP(S) GET. Headers apply to this request only, not redirects
  /// or subresources. No automatic retries that might duplicate transactions.
  Future<void> load(Uri uri, {Map<String, String> headers = const {}}) async {
    await initialize();
    final request = ++_request;
    if (!await _allow(uri)) {
      throw NivorquillFailure('blocked', 'Navigation denied', uri: uri);
    }
    _ensureAlive();
    if (request != _request) {
      throw const NivorquillFailure('superseded', 'A newer load was requested');
    }
    final safeHeaders = Map<String, String>.unmodifiable(headers);
    _localHtmlMode = false;
    await _load(uri, () => _engine.load(uri, safeHeaders));
  }

  /// Loads trusted application HTML. This bypasses remote-origin rules for
  /// the initial document; sanitize untrusted HTML and use CSP yourself.
  Future<void> loadHtml(String html, {Uri? baseUrl}) async {
    await initialize();
    _ensureAlive();
    ++_request;
    if (baseUrl != null && !settings.policy.allows(baseUrl)) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Disallowed base URL');
    }
    _localHtmlMode = true;
    await _load(
      baseUrl ?? Uri.parse('about:blank'),
      () => _engine.loadHtml(html, baseUrl),
    );
  }

  Future<void> _load(Uri uri, Future<void> Function() action) async {
    _started(uri.toString());
    final generation = _generation;
    try {
      await action();
      _ensureAlive();
    } catch (error) {
      if (generation == _generation) {
        _fail(NivorquillFailure('load', error.toString(), uri: uri));
      }
      rethrow;
    }
  }

  Future<bool> _allow(Uri uri) async {
    if (_disposed) {
      return false;
    }
    var allowed = settings.policy.allows(uri);
    if (allowed && navigationGuard != null) {
      try {
        allowed = await Future<bool>.sync(
          () => navigationGuard!(uri),
        ).timeout(settings.guardTimeout);
      } catch (_) {
        allowed = false; // Fail closed if the guard throws or times out.
      }
    }
    if (!allowed && !_disposed) {
      _emit(NivorquillEventKind.blocked, uri: uri);
    }
    return allowed && !_disposed;
  }

  void _started(String url) {
    if (_disposed) {
      return;
    }
    ++_generation;
    _loadTimer?.cancel();
    _loadWatch = Stopwatch()..start();
    _set(
      _state.copyWith(
        phase: NivorquillPhase.loading,
        uri: Uri.tryParse(url),
        progress: 0,
        clearFailure: true,
        clearPage: true,
      ),
    );
    _emit(NivorquillEventKind.started, uri: _state.uri);
    _loadTimer = Timer(settings.navigationTimeout, () {
      _fail(
        NivorquillFailure(
          'timeout',
          'Page load exceeded the time limit',
          uri: _state.uri,
        ),
      );
    });
  }

  Future<void> _finished(String url) async {
    if (_disposed || !_state.isLoading) {
      return;
    }
    final uri = Uri.tryParse(url);
    // Native callbacks do not carry navigation IDs. Ignore clearly stale URLs;
    // same-URL overlapping navigations still require device regression tests.
    if (_state.uri != null && uri != _state.uri) {
      return;
    }
    final generation = _generation;
    _loadTimer?.cancel();
    _loadWatch?.stop();
    _set(
      _state.copyWith(
        phase: NivorquillPhase.ready,
        uri: uri,
        progress: 100,
        elapsed: _loadWatch?.elapsed,
        clearFailure: true,
      ),
    );
    await _refreshMetadata(generation);
    for (final script in settings.pageFinishedScripts) {
      if (!_isCurrent(generation)) {
        return;
      }
      try {
        await _engine.runJavaScript(script).timeout(settings.scriptTimeout);
      } catch (error) {
        if (_isCurrent(generation)) {
          _emit(
            NivorquillEventKind.scriptFailure,
            failure: NivorquillFailure('script', error.toString()),
          );
        }
      }
    }
    if (_isCurrent(generation)) {
      _emit(NivorquillEventKind.finished, uri: uri);
    }
  }

  Future<void> _refreshMetadata(int generation) async {
    final request = ++_metadataRequest;
    try {
      final results = await Future.wait<Object?>([
        _engine.title(),
        _engine.canGoBack(),
        _engine.canGoForward(),
      ]).timeout(settings.scriptTimeout);
      if (!_isCurrent(generation) || request != _metadataRequest) {
        return;
      }
      _set(
        _state.copyWith(
          title: results[0] as String?,
          canGoBack: results[1]! as bool,
          canGoForward: results[2]! as bool,
        ),
      );
    } catch (_) {
      // Optional metadata failure must not turn a loaded page into an error.
    }
  }

  void _fail(NivorquillFailure error) {
    if (_disposed) {
      return;
    }
    // Ignore a clearly stale native error from a different URL.
    if (error.uri != null &&
        error.uri.toString().isNotEmpty &&
        _state.uri != null &&
        error.uri != _state.uri) {
      return;
    }
    _loadTimer?.cancel();
    _loadWatch?.stop();
    _set(
      _state.copyWith(
        phase: NivorquillPhase.failed,
        failure: error,
        elapsed: _loadWatch?.elapsed,
      ),
    );
    _emit(NivorquillEventKind.failure, failure: error, uri: error.uri);
  }

  Future<void> reload() async {
    await initialize();
    _ensureAlive();
    final request = ++_request;
    final url = await _engine.currentUrl();
    _ensureAlive();
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || !await _allow(uri)) {
      throw const NivorquillFailure(
        'blocked',
        'Reload requires an allowed URL',
      );
    }
    _ensureAlive();
    if (request != _request) {
      throw const NivorquillFailure('superseded', 'A newer load was requested');
    }
    await _load(uri, _engine.reload);
  }

  /// Explicitly retry a failed remote GET using its last recorded URL.
  Future<void> retry() async {
    final uri = _state.failure?.uri ?? _state.uri;
    if (uri == null || !settings.policy.allows(uri)) {
      throw const NivorquillFailure(
        'retry_unavailable',
        'No allowed remote URL to retry',
      );
    }
    await load(uri);
  }

  Future<bool> goBack() => _history(back: true);
  Future<bool> goForward() => _history(back: false);

  Future<bool> _history({required bool back}) async {
    await initialize();
    final available = await (back
        ? _engine.canGoBack()
        : _engine.canGoForward());
    _ensureAlive();
    if (!available) {
      return false;
    }
    ++_request;
    ++_generation;
    await (back ? _engine.goBack() : _engine.goForward());
    _ensureAlive();
    return true;
  }

  /// Evaluates a synchronous JS expression and decodes a JSON-safe result.
  Future<Object?> evaluateJson(String expression) async {
    await initialize();
    _ensureScripts();
    final generation = _generation;
    final result = await _engine
        .evaluate(PageScripts.json(expression))
        .timeout(settings.scriptTimeout);
    _ensureGeneration(generation);
    return _decodeEnvelope(result);
  }

  /// Awaits a Promise without exposing a JS-to-native privileged bridge.
  /// Timeout ends Dart waiting; it cannot cancel JS or network side effects.
  Future<Object?> evaluateAsyncJson(
    String expression, {
    Duration? timeout,
  }) async {
    await initialize();
    _ensureScripts();
    if (_activeScripts >= 16) {
      throw StateError('At most 16 asynchronous scripts may run concurrently');
    }
    final limit = timeout ?? settings.scriptTimeout;
    if (limit <= Duration.zero) {
      throw ArgumentError.value(limit, 'timeout');
    }
    final generation = _generation;
    final key =
        '__nivorquill_${DateTime.now().microsecondsSinceEpoch}_'
        '${Random.secure().nextInt(1 << 32)}';
    ++_activeScripts;
    final watch = Stopwatch()..start();
    Duration remaining() {
      final left = limit - watch.elapsed;
      if (left <= Duration.zero) {
        throw TimeoutException('Script timed out', limit);
      }
      return left;
    }

    try {
      await _engine
          .runJavaScript(PageScripts.startAsync(key, expression))
          .timeout(remaining());
      while (true) {
        _ensureGeneration(generation);
        final raw = await _engine
            .evaluate(PageScripts.poll(key))
            .timeout(remaining());
        _ensureGeneration(generation);
        final status = _decodeObject(raw);
        if (status.containsKey('result')) {
          return _decodeEnvelope(status['result']!);
        }
        if (status['missing'] == true) {
          throw const NivorquillFailure(
            'context_lost',
            'Script context was lost',
          );
        }
        final delay = remaining();
        await Future<void>.delayed(
          delay < const Duration(milliseconds: 30)
              ? delay
              : const Duration(milliseconds: 30),
        );
      }
    } finally {
      --_activeScripts;
      if (_isCurrent(generation)) {
        try {
          await _engine
              .runJavaScript(PageScripts.remove(key))
              .timeout(const Duration(milliseconds: 250));
        } catch (_) {
          /* Best-effort release after navigation or native loss. */
        }
      }
    }
  }

  static Map<String, Object?> _decodeObject(Object raw) {
    Object? decoded = raw is String ? jsonDecode(raw) : raw;
    // Some native adapters return a JSON-quoted JS string.
    if (decoded is String) {
      decoded = jsonDecode(decoded);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('WebView returned an invalid JSON envelope');
    }
    return Map<String, Object?>.from(decoded);
  }

  static Object? _decodeEnvelope(Object raw) {
    final data = _decodeObject(raw);
    if (data['ok'] == true) {
      return data['value'];
    }
    throw NivorquillFailure(
      'javascript',
      data['error']?.toString() ?? 'JS failed',
    );
  }

  Future<void> injectCss(String css, {String id = 'nivorquill-style'}) async {
    await initialize();
    _ensureScripts();
    await _engine
        .runJavaScript(PageScripts.css(css, id))
        .timeout(settings.scriptTimeout);
  }

  /// Uses WebKit/Chromium window.find; searches the rendered page, wraps, and
  /// selects a match. No total count, PDF search or cross-origin iframe promise.
  Future<bool> findText(
    String query, {
    bool backwards = false,
    bool caseSensitive = false,
  }) async {
    if (query.isEmpty) {
      return false;
    }
    return await evaluateJson(
          PageScripts.find(
            query,
            backwards: backwards,
            caseSensitive: caseSensitive,
          ),
        ) ==
        true;
  }

  Future<Map<String, Object?>> pageMetadata() async =>
      Map<String, Object?>.from(
        (await evaluateJson(PageScripts.metadata))! as Map<String, Object?>,
      );

  Future<void> scrollTo(int x, int y) async {
    await initialize();
    _ensureAlive();
    await _engine.scrollTo(x, y);
  }

  /// Scroll by a relative offset in the native WebView's coordinate system.
  Future<void> scrollBy(int x, int y) async {
    await initialize();
    _ensureAlive();
    await _engine.scrollBy(x, y);
  }

  /// Returns the current native scroll position.
  Future<Offset> scrollPosition() async {
    await initialize();
    _ensureAlive();
    return _engine.scrollPosition();
  }

  /// Cache clearing does not reload the page or clear cookies.
  Future<void> clearCache() async {
    await initialize();
    _ensureAlive();
    await _engine.clearCache();
  }

  /// Native web storage is shared by default. This is not per-view isolation.
  Future<void> clearLocalStorage() async {
    await initialize();
    _ensureAlive();
    await _engine.clearLocalStorage();
  }

  void _ensureScripts() {
    _ensureAlive();
    if (!settings.javaScriptEnabled) {
      throw StateError('JavaScript is disabled');
    }
  }

  void _ensureAlive() {
    if (_disposed) {
      throw StateError('NivorquillController has been disposed');
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _ensureGeneration(int generation) {
    _ensureAlive();
    if (!_isCurrent(generation)) {
      throw const NivorquillFailure(
        'navigation_changed',
        'The page navigated while JavaScript was running',
      );
    }
  }

  void _set(NivorquillState state) {
    if (_disposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  void _emit(NivorquillEventKind kind, {Uri? uri, NivorquillFailure? failure}) {
    if (!_disposed) {
      _events.add(NivorquillEvent(kind, uri: uri, failure: failure));
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    ++_generation;
    ++_request;
    _loadTimer?.cancel();
    _loadWatch?.stop();
    unawaited(_events.close());
    // webview_flutter owns native view lifetime; it has no controller.dispose.
    super.dispose();
  }
}
