import 'dart:async';
import 'dart:ui';
import 'package:nivorquill_webview/src/engine.dart';
import 'package:nivorquill_webview/src/models.dart';

class FakeEngine implements NivorquillEngine {
  late EngineCallbacks callbacks;
  int initializations = 0;
  int loads = 0;
  int backCalls = 0;
  String? url;
  bool backAvailable = false;
  Completer<void>? initialization;
  Completer<Object>? evaluation;
  Object evaluationResult = '{"ok":true,"value":42}';
  final scripts = <String>[];
  Object? loadError;
  Map<String, String>? headers;
  Offset position = Offset.zero;
  NivorquillSettings? settings;

  @override
  Future<void> initialize(NivorquillSettings s, EngineCallbacks c) async {
    ++initializations;
    settings = s;
    callbacks = c;
    if (initialization != null) {
      await initialization!.future;
    }
  }

  @override
  Future<void> load(Uri uri, Map<String, String> headers) async {
    ++loads;
    url = uri.toString();
    this.headers = headers;
    if (loadError != null) {
      throw loadError!;
    }
  }

  @override
  Future<void> loadHtml(String html, Uri? baseUrl) async {
    ++loads;
    url = baseUrl?.toString() ?? 'about:blank';
  }

  @override
  Future<void> reload() async {
    ++loads;
  }

  @override
  Future<void> goBack() async {
    ++backCalls;
  }

  @override
  Future<void> goForward() async {}
  @override
  Future<bool> canGoBack() async => backAvailable;
  @override
  Future<bool> canGoForward() async => false;
  @override
  Future<String?> title() async => 'Test page';
  @override
  Future<String?> currentUrl() async => url;
  @override
  Future<void> runJavaScript(String source) async {
    scripts.add(source);
  }

  @override
  Future<Object> evaluate(String source) async =>
      evaluation == null ? evaluationResult : await evaluation!.future;
  @override
  Future<void> scrollTo(int x, int y) async {
    position = Offset(x.toDouble(), y.toDouble());
  }

  @override
  Future<void> scrollBy(int x, int y) async {
    position += Offset(x.toDouble(), y.toDouble());
  }

  @override
  Future<Offset> scrollPosition() async => position;
  @override
  Future<void> clearCache() async {}
  @override
  Future<void> clearLocalStorage() async {}
}
