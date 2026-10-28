import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivorquill_webview/nivorquill_webview.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'fake_engine.dart';

void main() {
  late FakeEngine engine;
  late NivorquillController controller;

  setUp(() {
    engine = FakeEngine();
    controller = NivorquillController.withEngine(engine);
  });
  tearDown(() => controller.dispose());

  test('blocked navigation invokes the app callback', () async {
    controller.dispose();
    final blocked = <Uri>[];
    controller = NivorquillController.withEngine(
      engine,
      settings: NivorquillSettings(onNavigationBlocked: blocked.add),
    );
    await controller.initialize();
    expect(
      await engine.callbacks.navigate('mailto:help@example.com', true),
      isFalse,
    );
    expect(blocked, [Uri.parse('mailto:help@example.com')]);
  });

  test(
    'HTTP error overlay is opt-in and ignores errors for other URLs',
    () async {
      final uri = Uri.parse('https://example.com/page');
      HttpResponseError response(int status, Uri? requestUri) =>
          HttpResponseError(
            request: requestUri == null
                ? null
                : WebResourceRequest(uri: requestUri),
            response: WebResourceResponse(uri: null, statusCode: status),
          );
      await controller.load(uri);
      engine.callbacks.httpError(response(500, uri));
      expect(controller.state.phase, NivorquillPhase.loading);
      controller.dispose();
      var observed = 0;
      controller = NivorquillController.withEngine(
        engine,
        settings: NivorquillSettings(
          showHttpErrorPage: true,
          onHttpError: (_) => observed++,
        ),
      );
      await controller.load(uri);
      engine.callbacks.httpError(
        response(500, Uri.parse('https://example.com/image')),
      );
      engine.callbacks.httpError(response(404, uri));
      expect(controller.state.phase, NivorquillPhase.loading);
      engine.callbacks.httpError(response(500, null));
      expect(controller.state.failure?.code, 'http:500');
      expect(observed, 3);
      engine.callbacks.finished(uri.toString());
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.phase, NivorquillPhase.failed);
    },
  );

  test('HTTP error status selection is customizable', () async {
    controller.dispose();
    controller = NivorquillController.withEngine(
      engine,
      settings: NivorquillSettings(
        showHttpErrorPage: true,
        httpErrorStatusCodes: (status) => status == 404,
      ),
    );
    final uri = Uri.parse('https://example.com/page');
    await controller.load(uri);
    engine.callbacks.httpError(
      HttpResponseError(
        request: WebResourceRequest(uri: uri),
        response: const WebResourceResponse(uri: null, statusCode: 404),
      ),
    );
    expect(controller.state.failure?.code, 'http:404');
  });

  test('retry requires an allowed remote page and starts a new GET', () async {
    await expectLater(controller.retry(), throwsA(isA<NivorquillFailure>()));
    final uri = Uri.parse('https://example.com/failing');
    await controller.load(uri);
    engine.callbacks.failed(NivorquillFailure('network', 'offline', uri: uri));
    await controller.retry();
    expect(engine.loads, 2);
    expect(engine.url, uri.toString());
    expect(controller.state.phase, NivorquillPhase.loading);
  });

  test(
    'scroll operations initialize and preserve relative positioning',
    () async {
      await controller.scrollTo(10, 20);
      await controller.scrollBy(-3, 5);
      expect(await controller.scrollPosition(), const Offset(7, 25));
      expect(engine.initializations, 1);
      controller.dispose();
      await expectLater(controller.scrollPosition(), throwsStateError);
    },
  );

  test('custom view settings are passed to the engine', () async {
    controller.dispose();
    controller = NivorquillController.withEngine(
      engine,
      settings: NivorquillSettings(
        backgroundColor: const Color(0xff123456),
        zoomEnabled: false,
        verticalScrollBarEnabled: false,
      ),
    );
    await controller.initialize();
    expect(engine.settings!.backgroundColor, const Color(0xff123456));
    expect(engine.settings!.zoomEnabled, isFalse);
    expect(engine.settings!.verticalScrollBarEnabled, isFalse);
  });

  test(
    'local HTML permits its blank document without opening remote policy',
    () async {
      await controller.loadHtml('<p>Local</p>');
      expect(await engine.callbacks.navigate('about:blank', true), isTrue);
      expect(
        await engine.callbacks.navigate('javascript:alert(1)', true),
        isFalse,
      );
      await controller.load(Uri.parse('https://example.com'));
      expect(await engine.callbacks.navigate('about:blank', true), isFalse);
    },
  );

  test(
    'a pending native guard cannot authorize a superseded navigation',
    () async {
      controller.dispose();
      final guard = Completer<bool>();
      controller = NivorquillController.withEngine(
        engine,
        navigationGuard: (uri) => uri.path == '/slow' ? guard.future : true,
      );
      await controller.initialize();
      final decision = engine.callbacks.navigate(
        'https://example.com/slow',
        true,
      );
      await Future<void>.delayed(Duration.zero);
      await controller.load(Uri.parse('https://example.com/new'));
      guard.complete(true);
      expect(await decision, isFalse);
    },
  );

  test('concurrent initialization shares one future and native call', () async {
    engine.initialization = Completer<void>();
    final a = controller.initialize();
    final b = controller.initialize();
    expect(identical(a, b), isTrue);
    expect(engine.initializations, 1);
    engine.initialization!.complete();
    await a;
    expect(controller.isInitialized, isTrue);
  });

  test('programmatic loads enforce policy before native load', () async {
    await expectLater(
      controller.load(Uri.parse('javascript:alert(1)')),
      throwsA(isA<NivorquillFailure>()),
    );
    expect(engine.loads, 0);
    await controller.load(Uri.parse('https://example.com'));
    expect(engine.loads, 1);
  });

  test('navigation guard exceptions and timeout fail closed', () async {
    for (final hangs in [false, true]) {
      final other = NivorquillController.withEngine(
        FakeEngine(),
        settings: NivorquillSettings(
          guardTimeout: const Duration(milliseconds: 5),
        ),
        navigationGuard: (_) =>
            hangs ? Completer<bool>().future : throw StateError('guard failed'),
      );
      await expectLater(
        other.load(Uri.parse('https://example.com')),
        throwsA(isA<NivorquillFailure>()),
      );
      other.dispose();
    }
  });

  test('latest load wins while an earlier async guard is pending', () async {
    controller.dispose();
    final guard = Completer<bool>();
    controller = NivorquillController.withEngine(
      engine,
      navigationGuard: (uri) => uri.path == '/slow' ? guard.future : true,
    );
    final first = controller.load(Uri.parse('https://example.com/slow'));
    final assertion = expectLater(first, throwsA(isA<NivorquillFailure>()));
    await Future<void>.delayed(Duration.zero);
    await controller.load(Uri.parse('https://example.com/new'));
    guard.complete(true);
    await assertion;
    expect(engine.url, 'https://example.com/new');
    expect(engine.loads, 1);
  });

  test('progress is bounded; stale finishes do not end a newer load', () async {
    await controller.load(Uri.parse('https://example.com/new'));
    engine.callbacks.progress(200);
    expect(controller.state.progress, 100);
    engine.callbacks.finished('https://example.com/old');
    expect(controller.state.isLoading, isTrue);
    engine.callbacks.finished('https://example.com/new');
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.phase, NivorquillPhase.ready);
    expect(controller.state.title, 'Test page');
  });

  test('late finish after network failure does not hide the error', () async {
    await controller.load(Uri.parse('https://example.com'));
    engine.callbacks.failed(const NivorquillFailure('network', 'offline'));
    engine.callbacks.finished('https://example.com');
    expect(controller.state.phase, NivorquillPhase.failed);
  });

  test('load timeout emits a failure and next load clears it', () async {
    controller.dispose();
    controller = NivorquillController.withEngine(
      engine,
      settings: NivorquillSettings(
        navigationTimeout: const Duration(milliseconds: 5),
      ),
    );
    final failure = controller.events.firstWhere(
      (event) => event.kind == NivorquillEventKind.failure,
    );
    await controller.load(Uri.parse('https://example.com'));
    expect((await failure).failure?.code, 'timeout');
    await controller.load(Uri.parse('https://example.com/next'));
    expect(controller.state.failure, isNull);
  });

  test('native errors are both surfaced in state and propagated', () async {
    engine.loadError = StateError('native failed');
    await expectLater(
      controller.load(Uri.parse('https://example.com')),
      throwsStateError,
    );
    expect(controller.state.failure?.code, 'load');
  });

  test('disposal during initialization prevents queued load', () async {
    engine.initialization = Completer<void>();
    final load = controller.load(Uri.parse('https://example.com'));
    final assertion = expectLater(load, throwsStateError);
    controller.dispose();
    engine.initialization!.complete();
    await assertion;
    expect(engine.loads, 0);
  });

  test('navigation invalidates a pending JavaScript result', () async {
    await controller.initialize();
    engine.evaluation = Completer<Object>();
    final result = controller.evaluateJson('42');
    final assertion = expectLater(result, throwsA(isA<NivorquillFailure>()));
    await Future<void>.delayed(Duration.zero);
    engine.callbacks.started('https://example.com/new');
    engine.evaluation!.complete('{"ok":true,"value":42}');
    await assertion;
  });

  test('JSON values decode on both native string encodings', () async {
    for (final value in [
      null,
      true,
      42,
      'hello',
      [1, 2],
      {'x': 1},
    ]) {
      for (final doubleEncoded in [false, true]) {
        final payload = jsonEncode({'ok': true, 'value': value});
        engine.evaluationResult = doubleEncoded ? jsonEncode(payload) : payload;
        expect(await controller.evaluateJson('null'), value);
      }
    }
    engine.evaluationResult = '{"ok":false,"error":"failed"}';
    await expectLater(
      controller.evaluateJson('null'),
      throwsA(isA<NivorquillFailure>()),
    );
  });

  test('async scripts return results and remove their result slot', () async {
    engine.evaluationResult = jsonEncode({
      'result': jsonEncode({
        'ok': true,
        'value': {'answer': 42},
      }),
    });
    expect(await controller.evaluateAsyncJson('Promise.resolve(42)'), {
      'answer': 42,
    });
    expect(engine.scripts.last, startsWith('delete window['));
  });

  test('async timeout cleans up and disabled scripting throws', () async {
    engine.evaluationResult = '{"pending":true}';
    await expectLater(
      controller.evaluateAsyncJson(
        'new Promise(() => {})',
        timeout: const Duration(milliseconds: 5),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(engine.scripts.last, startsWith('delete window['));
    final other = NivorquillController.withEngine(
      FakeEngine(),
      settings: NivorquillSettings(javaScriptEnabled: false),
    );
    await expectLater(other.evaluateJson('1'), throwsStateError);
    other.dispose();
  });

  test('history returns whether navigation was available', () async {
    expect(await controller.goBack(), isFalse);
    engine.backAvailable = true;
    expect(await controller.goBack(), isTrue);
    expect(engine.backCalls, 1);
  });

  test('callbacks after disposal cannot update listeners', () async {
    await controller.initialize();
    var calls = 0;
    controller.addListener(() {
      ++calls;
    });
    controller.dispose();
    engine.callbacks.started('https://example.com');
    engine.callbacks.progress(40);
    engine.callbacks.finished('https://example.com');
    engine.callbacks.failed(const NivorquillFailure('x', 'late'));
    expect(calls, 0);
    await expectLater(
      controller.load(Uri.parse('https://example.com')),
      throwsStateError,
    );
  });
}
