import 'dart:ui';

import 'package:webview_flutter/webview_flutter.dart';

import 'engine.dart';
import 'models.dart';

final class FlutterWebEngine implements NivorquillEngine {
  FlutterWebEngine(this.controller);
  final WebViewController controller;

  @override
  Future<void> initialize(
    NivorquillSettings settings,
    EngineCallbacks c,
  ) async {
    await controller.setJavaScriptMode(
      settings.javaScriptEnabled
          ? JavaScriptMode.unrestricted
          : JavaScriptMode.disabled,
    );
    if (settings.userAgent != null) {
      await controller.setUserAgent(settings.userAgent);
    }
    if (settings.backgroundColor case final color?) {
      await controller.setBackgroundColor(color);
    }
    if (settings.zoomEnabled case final enabled?) {
      await controller.enableZoom(enabled);
    }
    if (settings.onConsoleMessage case final callback?) {
      await controller.setOnConsoleMessage(callback);
    }
    if (settings.onScroll case final callback?) {
      await controller.setOnScrollPositionChange(
        (position) => callback(Offset(position.x, position.y)),
      );
    }
    if (settings.onJavaScriptAlert case final callback?) {
      await controller.setOnJavaScriptAlertDialog(callback);
    }
    if (settings.onJavaScriptConfirm case final callback?) {
      await controller.setOnJavaScriptConfirmDialog(callback);
    }
    if (settings.onJavaScriptPrompt case final callback?) {
      await controller.setOnJavaScriptTextInputDialog(callback);
    }
    if (settings.verticalScrollBarEnabled != null ||
        settings.horizontalScrollBarEnabled != null) {
      if (!await controller.supportsSetScrollBarsEnabled()) {
        throw UnsupportedError(
          'Scrollbar configuration is not supported on this platform',
        );
      }
      if (settings.verticalScrollBarEnabled case final enabled?) {
        await controller.setVerticalScrollBarEnabled(enabled);
      }
      if (settings.horizontalScrollBarEnabled case final enabled?) {
        await controller.setHorizontalScrollBarEnabled(enabled);
      }
    }
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onHttpError: c.httpError,
        onHttpAuthRequest: settings.onHttpAuth == null
            ? null
            : (request) async {
                try {
                  final credential = await settings.onHttpAuth!(request)
                      .timeout(settings.interactionTimeout);
                  if (credential == null) {
                    request.onCancel();
                  } else {
                    request.onProceed(credential);
                  }
                } catch (_) {
                  request.onCancel();
                }
              },
        onPageStarted: c.started,
        onPageFinished: c.finished,
        onProgress: c.progress,
        onUrlChange: (change) {
          if (change.url != null) {
            c.urlChanged(change.url!);
          }
        },
        onNavigationRequest: (request) async =>
            await c.navigate(request.url, request.isMainFrame)
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) {
            c.failed(
              NivorquillFailure(
                'network:${error.errorCode}',
                error.description,
                uri: Uri.tryParse(error.url ?? ''),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Future<void> load(Uri uri, Map<String, String> headers) =>
      controller.loadRequest(uri, headers: headers);
  @override
  Future<void> loadHtml(String html, Uri? baseUrl) =>
      controller.loadHtmlString(html, baseUrl: baseUrl?.toString());
  @override
  Future<void> reload() => controller.reload();
  @override
  Future<void> goBack() => controller.goBack();
  @override
  Future<void> goForward() => controller.goForward();
  @override
  Future<bool> canGoBack() => controller.canGoBack();
  @override
  Future<bool> canGoForward() => controller.canGoForward();
  @override
  Future<String?> title() => controller.getTitle();
  @override
  Future<String?> currentUrl() => controller.currentUrl();
  @override
  Future<void> runJavaScript(String source) => controller.runJavaScript(source);
  @override
  Future<Object> evaluate(String source) =>
      controller.runJavaScriptReturningResult(source);
  @override
  Future<void> scrollTo(int x, int y) => controller.scrollTo(x, y);
  @override
  Future<void> scrollBy(int x, int y) => controller.scrollBy(x, y);
  @override
  Future<Offset> scrollPosition() => controller.getScrollPosition();
  @override
  Future<void> clearCache() => controller.clearCache();
  @override
  Future<void> clearLocalStorage() => controller.clearLocalStorage();
}
