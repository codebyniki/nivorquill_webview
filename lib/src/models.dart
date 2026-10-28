import 'dart:async';
import 'dart:ui';

import 'package:webview_flutter/webview_flutter.dart';

import 'policy.dart';

/// The current stage of a page load.
enum NivorquillPhase {
  /// No page is currently loading.
  idle,

  /// The native WebView is being initialized.
  initializing,

  /// A page load is in progress.
  loading,

  /// The current page has finished loading.
  ready,

  /// The current page or initialization failed.
  failed,
}

/// The kind of activity reported by a controller event.
enum NivorquillEventKind {
  /// A page started loading.
  started,

  /// A page finished loading.
  finished,

  /// A navigation was denied by policy or the guard.
  blocked,

  /// A load or initialization failed.
  failure,

  /// A configured page-finished script failed.
  scriptFailure,
}

/// A failure reported by a controller operation or event.
final class NivorquillFailure implements Exception {
  /// Creates a failure with a machine-readable [code] and descriptive [message].
  const NivorquillFailure(this.code, this.message, {this.uri});

  /// Machine-readable failure category, such as `http:500` or `timeout`.
  final String code;

  /// Human-readable explanation of the failure.
  final String message;

  /// URL associated with the failure, when available.
  final Uri? uri;

  @override
  String toString() => 'NivorquillFailure($code): $message';
}

/// An immutable snapshot of a controller’s page state.
final class NivorquillState {
  /// Creates a page state snapshot, initially idle by default.
  const NivorquillState({
    this.phase = NivorquillPhase.idle,
    this.uri,
    this.title,
    this.progress = 0,
    this.canGoBack = false,
    this.canGoForward = false,
    this.elapsed,
    this.failure,
  });

  /// Current initialization or page-loading phase.
  final NivorquillPhase phase;

  /// Current URL when known.
  final Uri? uri;

  /// Current document title when known.
  final String? title;

  /// Loading progress from 0 to 100.
  final int progress;

  /// Whether a previous history entry is available.
  final bool canGoBack;

  /// Whether a next history entry is available.
  final bool canGoForward;

  /// Elapsed duration of the current or most recent load, when known.
  final Duration? elapsed;

  /// Most recent active load failure, if any.
  final NivorquillFailure? failure;

  /// Whether [phase] is [NivorquillPhase.loading].
  bool get isLoading => phase == NivorquillPhase.loading;

  /// Copies this snapshot with selected values replaced.
  ///
  /// [clearFailure] removes the failure; [clearPage] clears title and elapsed time.
  NivorquillState copyWith({
    NivorquillPhase? phase,
    Uri? uri,
    String? title,
    int? progress,
    bool? canGoBack,
    bool? canGoForward,
    Duration? elapsed,
    NivorquillFailure? failure,
    bool clearFailure = false,
    bool clearPage = false,
  }) => NivorquillState(
    phase: phase ?? this.phase,
    uri: uri ?? this.uri,
    title: clearPage ? null : (title ?? this.title),
    progress: progress ?? this.progress,
    canGoBack: canGoBack ?? this.canGoBack,
    canGoForward: canGoForward ?? this.canGoForward,
    elapsed: clearPage ? null : (elapsed ?? this.elapsed),
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// A timestamped controller activity emitted on the events stream.
final class NivorquillEvent {
  /// Creates an event with optional associated URI and failure.
  NivorquillEvent(this.kind, {this.uri, this.failure})
    : timestamp = DateTime.now();

  /// The activity represented by this event.
  final NivorquillEventKind kind;

  /// The time at which the event was created.
  final DateTime timestamp;

  /// URL associated with the event, when available.
  final Uri? uri;

  /// Failure associated with the event, when available.
  final NivorquillFailure? failure;
}

/// Decides whether a policy-allowed navigation may proceed.
///
/// The callback can run multiple times and should be idempotent. Errors and
/// timeouts deny navigation.
typedef NivorquillNavigationGuard = FutureOr<bool> Function(Uri uri);

/// Configuration applied when a controller initializes its native WebView.
final class NivorquillSettings {
  /// Creates settings with HTTPS navigation, JavaScript and default timeouts.
  ///
  /// Timeouts must be positive. Page-finished scripts require JavaScript.
  NivorquillSettings({
    NivorquillPolicy? policy,
    this.javaScriptEnabled = true,
    this.userAgent,
    this.backgroundColor,
    this.zoomEnabled,
    this.verticalScrollBarEnabled,
    this.horizontalScrollBarEnabled,
    this.onHttpError,
    this.showHttpErrorPage = false,
    this.httpErrorStatusCodes,
    this.onConsoleMessage,
    this.onScroll,
    this.onJavaScriptAlert,
    this.onJavaScriptConfirm,
    this.onJavaScriptPrompt,
    this.onHttpAuth,
    this.onPermissionRequest,
    this.navigationTimeout = const Duration(seconds: 30),
    this.guardTimeout = const Duration(seconds: 5),
    this.interactionTimeout = const Duration(seconds: 60),
    this.scriptTimeout = const Duration(seconds: 5),
    List<String> pageFinishedScripts = const [],
  }) : policy = policy ?? NivorquillPolicy(),
       pageFinishedScripts = List.unmodifiable(pageFinishedScripts) {
    for (final duration in [
      navigationTimeout,
      guardTimeout,
      interactionTimeout,
      scriptTimeout,
    ]) {
      if (duration <= Duration.zero) {
        throw ArgumentError('Timeouts must be positive');
      }
    }
    if (!javaScriptEnabled && pageFinishedScripts.isNotEmpty) {
      throw ArgumentError('Page scripts require javaScriptEnabled');
    }
  }

  /// Rules used to evaluate remote navigation.
  final NivorquillPolicy policy;

  /// Whether JavaScript runs in the WebView; defaults to true.
  final bool javaScriptEnabled;

  /// Custom user agent, or null to retain the platform default.
  final String? userAgent;

  /// Native WebView background color, or null for the platform default.
  final Color? backgroundColor;

  /// Whether native zoom gestures are enabled, or null for the platform default.
  final bool? zoomEnabled;

  /// Vertical scrollbar visibility, or null for the platform default.
  final bool? verticalScrollBarEnabled;

  /// Horizontal scrollbar visibility, or null for the platform default.
  final bool? horizontalScrollBarEnabled;

  /// Receives HTTP errors, including possible subresource errors.
  final void Function(HttpResponseError)? onHttpError;

  /// Whether qualifying HTTP errors show the view’s error overlay.
  ///
  /// Identification is best effort because frame and URL data can be missing.
  final bool showHttpErrorPage;

  /// Selects HTTP statuses for the overlay; null selects 500–599.
  final bool Function(int statusCode)? httpErrorStatusCodes;

  /// Receives JavaScript console output when provided; messages may contain sensitive data.
  final void Function(JavaScriptConsoleMessage)? onConsoleMessage;

  /// Receives native WebView scroll positions when they change.
  final void Function(Offset)? onScroll;

  /// Handles a page’s JavaScript alert dialog.
  final Future<void> Function(JavaScriptAlertDialogRequest)? onJavaScriptAlert;

  /// Handles a JavaScript confirmation and returns the user’s decision.
  final Future<bool> Function(JavaScriptConfirmDialogRequest)?
  onJavaScriptConfirm;

  /// Handles a JavaScript prompt and returns its text result.
  final Future<String> Function(JavaScriptTextInputDialogRequest)?
  onJavaScriptPrompt;

  /// Returns HTTP authentication credentials, or null to cancel.
  final Future<WebViewCredential?> Function(HttpAuthRequest)? onHttpAuth;

  /// Returns whether to grant all requested resources; errors and timeouts deny.
  final Future<bool> Function(WebViewPermissionRequest)? onPermissionRequest;

  /// Maximum load time before failure; defaults to 30 seconds.
  final Duration navigationTimeout;

  /// Maximum navigation guard decision time; defaults to 5 seconds.
  final Duration guardTimeout;

  /// Maximum authentication or permission decision time; defaults to 60 seconds.
  final Duration interactionTimeout;

  /// Default JavaScript operation timeout; defaults to 5 seconds.
  final Duration scriptTimeout;

  /// Trusted scripts run sequentially after a page finishes loading.
  final List<String> pageFinishedScripts;
}
