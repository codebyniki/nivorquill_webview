import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivorquill_webview/nivorquill_webview.dart';
import 'dart:async';

import 'fake_engine.dart';

void main() {
  testWidgets('HTTP-specific builder receives HTTP failures', (tester) async {
    final engine = FakeEngine()..initialization = Completer<void>();
    final controller = NivorquillController.withEngine(engine);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NivorquillView(
            controller: controller,
            httpErrorBuilder: (_, error) => Text('Custom ${error.code}'),
            errorBuilder: (_, _) => const Text('Generic error'),
          ),
        ),
      ),
    );
    engine.initialization!.completeError(
      const NivorquillFailure('http:500', 'Server error'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Custom http:500'), findsOneWidget);
    expect(find.text('Generic error'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('view initialization does not notify listeners during build', (
    tester,
  ) async {
    final engine = FakeEngine()..initialization = Completer<void>();
    final controller = NivorquillController.withEngine(engine);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ListenableBuilder(
                listenable: controller,
                builder: (_, _) => const Text('State'),
              ),
              Expanded(child: NivorquillView(controller: controller)),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    engine.initialization!.complete();
    await tester.pump();
  });
  testWidgets('error panel renders supplied content and invokes retry', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NivorquillErrorPanel(
            child: const Text('Offline'),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.text('Offline'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('error panel omits retry when no handler is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NivorquillErrorPanel())),
    );
    expect(find.text('Retry'), findsNothing);
  });
}
