import 'dart:async';
import 'dart:ui';

import 'package:webview_flutter/webview_flutter.dart';

import 'policy.dart';

enum NivorquillPhase { idle, initializing, loading, ready, failed }

enum NivorquillEventKind { started, finished, blocked, failure, scriptFailure }

final class NivorquillFailure implements Exception {
  const NivorquillFailure(this.code, this.message, {this.uri});
  final String code;
  final String message;
  final Uri? uri;

  @override
  String toString() => 'NivorquillFailure($code): $message';
}

final class NivorquillState {
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
  final NivorquillPhase phase;
  final Uri? uri;
  final String? title;
  final int progress;
  final bool canGoBack;
  final bool canGoForward;
  final Duration? elapsed;
  final NivorquillFailure? failure;
  bool get isLoading => phase == NivorquillPhase.loading;

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

final class NivorquillEvent {
  NivorquillEvent(this.kind, {this.uri, this.failure})
    : timestamp = DateTime.now();
  final NivorquillEventKind kind;
  final DateTime timestamp;
  final Uri? uri;
  final NivorquillFailure? failure;
}

/// This callback may run more than once for a navigation. Keep it idempotent.
typedef NivorquillNavigationGuard = FutureOr<bool> Function(Uri uri);

final class NivorquillSettings {
  NivorquillSettings({
    NivorquillPolicy? policy,
    this.javaScriptEnabled = true,
    this.userAgent,
    this.backgroundColor,
    this.zoomEnabled,
    this.verticalScrollBarEnabled,
    this.horizontalScrollBarEnabled,
    this.onHttpError,
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
  final NivorquillPolicy policy;
  final bool javaScriptEnabled;
  final String? userAgent;

  /// Native view background; null retains the platform default.
  final Color? backgroundColor;

  /// Whether user zoom gestures are enabled; null retains the platform default.
  final bool? zoomEnabled;

  /// Scrollbar visibility, or null to retain the platform default.
  final bool? verticalScrollBarEnabled;
  final bool? horizontalScrollBarEnabled;

  /// HTTP errors may include subresources; request metadata varies by platform.
  final void Function(HttpResponseError)? onHttpError;

  /// Opt-in: console output can contain sensitive page data.
  final void Function(JavaScriptConsoleMessage)? onConsoleMessage;
  final void Function(Offset)? onScroll;
  final Future<void> Function(JavaScriptAlertDialogRequest)? onJavaScriptAlert;
  final Future<bool> Function(JavaScriptConfirmDialogRequest)?
  onJavaScriptConfirm;
  final Future<String> Function(JavaScriptTextInputDialogRequest)?
  onJavaScriptPrompt;

  /// Return null to cancel; credentials are never stored by Nivorquill.
  final Future<WebViewCredential?> Function(HttpAuthRequest)? onHttpAuth;

  /// Return true to grant the requested resources, false to deny.
  final Future<bool> Function(WebViewPermissionRequest)? onPermissionRequest;
  final Duration navigationTimeout;
  final Duration guardTimeout;

  /// Time allowed for an app to resolve an authentication or permission prompt.
  final Duration interactionTimeout;
  final Duration scriptTimeout;

  /// Trusted application code, run after onPageFinished. Not document-start.
  final List<String> pageFinishedScripts;
}
