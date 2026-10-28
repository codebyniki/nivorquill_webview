import 'package:flutter/material.dart';
import 'controller.dart';

/// Optional toolbar; action errors are returned to the caller via [onError].
class NivorquillNavigationBar extends StatelessWidget {
  const NivorquillNavigationBar({
    super.key,
    required this.controller,
    this.onError,
  });
  final NivorquillController controller;
  final void Function(Object error)? onError;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      onError?.call(error);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: controller.state.canGoBack
              ? () => _run(() async {
                  await controller.goBack();
                })
              : null,
          icon: const Icon(Icons.arrow_back),
        ),
        IconButton(
          tooltip: 'Forward',
          onPressed: controller.state.canGoForward
              ? () => _run(() async {
                  await controller.goForward();
                })
              : null,
          icon: const Icon(Icons.arrow_forward),
        ),
        IconButton(
          tooltip: 'Reload',
          onPressed: () => _run(controller.reload),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
  );
}

/// Customizable error or offline content with an optional user-initiated retry.
class NivorquillErrorPanel extends StatelessWidget {
  const NivorquillErrorPanel({
    super.key,
    this.message = 'Unable to load this page.',
    this.onRetry,
    this.child,
  });
  final String message;
  final VoidCallback? onRetry;
  final Widget? child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child ?? Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    ),
  );
}
