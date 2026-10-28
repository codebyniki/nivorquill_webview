import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nivorquill_webview/nivorquill_webview.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real native view: HTML, JS, Promise, CSS, policy, disposal', (
    tester,
  ) async {
    final controller = NivorquillController();
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NivorquillView(controller: controller)),
      ),
    );
    await tester.pump();
    final done = controller.events.firstWhere(
      (event) => event.kind == NivorquillEventKind.finished,
    );
    await controller.loadHtml(
      '<!doctype html><html><head><title>Smoke test</title>'
      '</head><body><h1>Nivorquill</h1><p>Hello device</p></body></html>',
    );
    await done.timeout(const Duration(seconds: 30));
    expect(controller.state.title, 'Smoke test');
    expect(await controller.evaluateJson('({answer: 42, text: "hello"})'), {
      'answer': 42,
      'text': 'hello',
    });
    expect(await controller.evaluateAsyncJson('Promise.resolve([1,2,3])'), [
      1,
      2,
      3,
    ]);
    await controller.injectCss('body { background: rgb(1, 2, 3); }');
    expect(
      await controller.evaluateJson(
        'getComputedStyle(document.body).backgroundColor',
      ),
      'rgb(1, 2, 3)',
    );
    expect(await controller.findText('Hello device'), isTrue);
    await expectLater(
      controller.load(Uri.parse('javascript:alert(1)')),
      throwsA(isA<NivorquillFailure>()),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
