import 'package:flutter/material.dart';
import 'controller.dart';
import 'models.dart';
import 'view.dart';

/// Optional back, forward and reload controls for a controller.
class NivorquillNavigationBar extends StatelessWidget {
  /// Creates navigation controls and an optional action error handler.
  const NivorquillNavigationBar({
    super.key,
    required this.controller,
    this.onError,
  });

  /// Controller whose history and reload actions are used.
  final NivorquillController controller;

  /// Receives errors from toolbar actions when provided.
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

/// An error or offline panel with an optional user-triggered retry button.
class NivorquillErrorPanel extends StatelessWidget {
  /// Creates a panel with a message or custom child and optional retry action.
  const NivorquillErrorPanel({
    super.key,
    this.message = 'Unable to load this page.',
    this.onRetry,
    this.child,
  });

  /// Text shown when [child] is not supplied.
  final String message;

  /// Action called when Retry is pressed; null hides the button.
  final VoidCallback? onRetry;

  /// Custom content displayed instead of [message].
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

/// Displays trusted application-provided HTML in a separate error WebView.
///
/// Use as an HTTP error overlay. The HTML is trusted app content and its
/// initial document bypasses navigation origin rules. JavaScript is disabled.
class NivorquillHtmlErrorPage extends StatefulWidget {
  /// Creates an error page from trusted [html].
  const NivorquillHtmlErrorPage({super.key, required this.html});

  /// Trusted HTML to display; a new value reloads the error document.
  final String html;

  @override
  State<NivorquillHtmlErrorPage> createState() =>
      _NivorquillHtmlErrorPageState();
}

class _NivorquillHtmlErrorPageState extends State<NivorquillHtmlErrorPage> {
  late final NivorquillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NivorquillController(
      settings: NivorquillSettings(javaScriptEnabled: false),
    );
    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant NivorquillHtmlErrorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      Future<void>.microtask(_load);
    }
  }

  Future<void> _load() async {
    try {
      await _controller.loadHtml(widget.html);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NivorquillView(controller: _controller);
}
